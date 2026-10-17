# vm-gui (v2.8.4): GUI apps from Xen VMs over vchan. dom0's wprsc talks to
# the VM's wprsd through nox-relay (/run/nox-relay/<vm>-wprs.sock) instead
# of an SSH tunnel; one wprsc per VM. The app is started by RPC (stage C3,
# `nox-rpc --dom0 app <vm>`, handler in vms/modules/vchan-relay.nix), VMs
# without it (sys-net, sys-usb) still over SSH. vm-run uses vm-gui for Xen
# guests with wprs over the relay.
{
  lib,
  pkgs,
  vmRegistry,
  ...
}:
let

  vmCases = lib.concatMapStrings (
    vm:
    "  ${vm.name}${
        lib.optionalString (vm.short != null && vm.short != vm.name) "|${vm.short}"
      }) VM=${vm.name}; IP=${vm.ip} ;;\n"
  ) (vmRegistry.vms ++ vmRegistry.imageDomains);

  vmGui = pkgs.writeShellScriptBin "vm-gui" ''
    set -eu
    if [ $# -lt 2 ]; then
      echo "usage: vm-gui <vm|short> <command> [args...]" >&2
      exit 2
    fi
    case "$1" in
    ${vmCases}
      *) echo "vm-gui: unknown VM: $1" >&2; exit 2 ;;
    esac
    shift

    fail() {
      echo "vm-gui: $1" >&2
      ${pkgs.libnotify}/bin/notify-send "vm-gui: $VM" "$1" || true
      exit 1
    }

    # The relay sockets appear once the VM's domain exists (VM just started)
    sock="/run/nox-relay/$VM-wprs.sock"
    rpc="/run/nox-relay/$VM-rpc-in.sock"
    for _ in $(seq 60); do
      [ -S "$sock" ] && break
      sleep 1
    done
    [ -S "$sock" ] || fail "$sock missing (does $VM run wprsd, is nox-relay-$VM up?)"

    run="''${XDG_RUNTIME_DIR:-/tmp}"
    pidfile="$run/wprsc-vchan-$VM.pid"
    # Locked: apps started together (niri spawn-at-startup) each saw no
    # pidfile and started their own wprsc (three for chat, 2026-10-15).
    # wprsc must not inherit the lock fd, it would hold the lock forever
    start_wprsc() {
      (
        ${pkgs.util-linux}/bin/flock 9
        if ! { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }; then
          # Title prefix: niri's border rule per trust label matches it
          # (home/desktop/niri.nix `labelRules`)
          setsid ${pkgs.wprs}/bin/wprsc --socket="$sock" \
            --control-socket="$run/wprsc-vchan-$VM-ctrl.sock" \
            --title-prefix="[$VM] " \
            >"$run/wprsc-vchan-$VM.log" 2>&1 9>&- &
          echo $! >"$pidfile"
          sleep 1
        fi
      ) 9>"$run/wprsc-vchan-$VM.lock"
    }

    # Same environment the wprs launcher sets for remote apps; over RPC the
    # VM sets it (apps.environment), only the cursor size comes from here
    cursor="XCURSOR_SIZE=''${XCURSOR_SIZE:-24}"
    if [ -S "$rpc" ]; then
      # Retry while the VM is still booting (the relay drops the call
      # without an answer); the handler answers "ok: ..." or "error: ...".
      # The app unit waits for wprsd, so wprsc comes after it
      answer=""
      for _ in $(seq 60); do
        answer="$(printf '%s\0' env "$cursor" "$@" | nox-rpc --dom0 app "$VM" 2>/dev/null)" || true
        [ -n "$answer" ] && break
        sleep 1
      done
      [[ "$answer" == ok* ]] || fail "start of $1 failed: ''${answer:-no answer}"
      start_wprsc
    else
      start_wprsc
      exec ${pkgs.openssh}/bin/ssh -i "$HOME/.ssh/$VM-vm" \
        -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
        "user@$IP" env WAYLAND_DISPLAY=wprs-0 DISPLAY=:100 XDG_SESSION_TYPE=wayland \
        PULSE_SERVER=unix:/tmp/wprs-pulse "$cursor" \
        "$(printf '%q ' "$@")"
    fi
  '';

  # Clipboard between domains (Qubes model): each VM keeps its own clipboard
  # (wprsd without selection sync, vms/modules/wprs.nix). `copy` takes the
  # text clipboard of the focused window's domain into a store in dom0,
  # `paste` hands it to the focused window's domain and empties the store.
  # Rules from the registry (`clipboard`); notifications never show content
  clipPolicy = vm: vm.clipboard or (if lib.hasPrefix "sys-" vm.name then "deny" else "allow");
  clipCases = lib.concatMapStrings (vm: "    ${vm.name}) echo ${clipPolicy vm} ;;\n") (
    vmRegistry.vms ++ vmRegistry.imageDomains
  );

  vmClip = pkgs.writeShellScriptBin "vm-clip" ''
    set -eu
    ssh() {
      ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 "$@"
    }
    notify() {
      ${pkgs.libnotify}/bin/notify-send -a vm-clip "Zwischenablage" "$1" || true
    }
    # Image domains (Whonix) keep it in /nix/store/nox/bin, not on the
    # session PATH
    helper='PATH="$PATH:/nix/store/nox/bin" vm-clip-helper'
    fail() {
      notify "$1"
      echo "vm-clip: $1" >&2
      exit 1
    }

    # Domain of the focused window: VM windows belong to dom0's wprsc for
    # that VM (vm-gui), everything else is dom0
    focused_domain() {
      local pid args dom
      pid="$(niri msg --json focused-window | ${pkgs.jq}/bin/jq -r '.pid // empty')"
      [ -n "$pid" ] || fail "Kein fokussiertes Fenster"
      args="$(tr '\0' '\n' <"/proc/$pid/cmdline")" || fail "Fensterprozess $pid nicht gefunden"
      case "$args" in
        */wprsc*)
          dom="$(sed -n 's|^--socket=/run/nox-relay/\(.*\)-wprs\.sock$|\1|p' <<<"$args")"
          [ -n "$dom" ] || fail "VM des Fensters unbekannt (wprsc ohne nox-relay)"
          ;;
        *) dom=dom0 ;;
      esac
      echo "$dom"
    }

    policy() {
      case "$1" in
        dom0) echo allow ;;
    ${clipCases}
        *) echo deny ;;
      esac
    }

    store="''${XDG_RUNTIME_DIR:?}/vm-clip"
    umask 077
    mkdir -p "$store"

    case "''${1:-}" in
      copy)
        src="$(focused_domain)"
        case "$(policy "$src")" in
          deny) fail "$src ist für die Zwischenablage gesperrt" ;;
          ask)
            answer="$(printf 'Nein\nJa\n' | rofi -dmenu -i -no-custom \
              -p "Zwischenablage aus $src kopieren?" \
              -theme ~/.config/rofi/config.rasi)" || answer=""
            [ "$answer" = Ja ] || fail "Kopieren aus $src abgebrochen"
            ;;
        esac
        if [ "$src" = dom0 ]; then
          ${pkgs.wl-clipboard}/bin/wl-paste --no-newline --type text >"$store/new" 2>/dev/null \
            || { rm -f "$store/new"; fail "dom0: keine Text-Zwischenablage"; }
        else
          ssh "$src" "$helper get" </dev/null >"$store/new" 2>/dev/null \
            || { rm -f "$store/new"; fail "$src: keine Text-Zwischenablage"; }
        fi
        mv "$store/new" "$store/data"
        echo "$src" >"$store/source"
        notify "Aus $src kopiert ($(wc -c <"$store/data") Bytes), einfügen mit Mod+Alt+V"
        ;;
      paste)
        [ -f "$store/data" ] || fail "Ablage leer, erst mit Mod+Alt+C kopieren"
        dst="$(focused_domain)"
        [ "$(policy "$dst")" != deny ] || fail "$dst ist für die Zwischenablage gesperrt"
        src="$(cat "$store/source")"
        size="$(wc -c <"$store/data")"
        if [ "$dst" = dom0 ]; then
          # wl-copy forks and keeps serving the selection
          ${pkgs.wl-clipboard}/bin/wl-copy --type text/plain <"$store/data" >/dev/null 2>&1
        else
          ssh "$dst" "$helper set" <"$store/data" || fail "Einfügen in $dst fehlgeschlagen"
        fi
        rm -f "$store/data" "$store/source"
        notify "$src → $dst ($size Bytes), einfügen mit Strg+V"
        ;;
      *)
        echo "usage: vm-clip copy|paste" >&2
        exit 2
        ;;
    esac
  '';
in
{
  home.packages = [
    vmGui
    vmClip
  ];
}
