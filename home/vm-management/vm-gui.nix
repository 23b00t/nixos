# vm-gui (v2.8.4): GUI apps from Xen VMs over vchan. dom0's wprsc talks to
# the VM's wprsd through nox-relay (/run/nox-relay/<vm>-wprs.sock) instead
# of an SSH tunnel; one wprsc per VM. The app is started by RPC (stage C3,
# `nox-rpc --dom0 app <vm>`, handler in vms/modules/vchan-relay.nix), VMs
# without it (sys-net, sys-usb) still over SSH. vm-run uses vm-gui for Xen
# guests with wprs over the relay.
{ lib, pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;

  vmCases = lib.concatMapStrings (
    vm:
    "  ${vm.name}${
        lib.optionalString (vm.short != null && vm.short != vm.name) "|${vm.short}"
      }) VM=${vm.name}; IP=${vm.ip} ;;\n"
  ) vmRegistry.vms;

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
    start_wprsc() {
      if ! { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }; then
        setsid ${pkgs.wprs}/bin/wprsc --socket="$sock" \
          --control-socket="$run/wprsc-vchan-$VM-ctrl.sock" \
          >"$run/wprsc-vchan-$VM.log" 2>&1 &
        echo $! >"$pidfile"
        sleep 1
      fi
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
in
{
  home.packages = [ vmGui ];
}
