# vm-gui (v2.8.4): GUI apps from Xen VMs over vchan. dom0's wprsc talks to
# the VM's wprsd through nox-relay (/run/nox-relay/<vm>-wprs.sock) instead
# of an SSH tunnel; one wprsc per VM. The app itself is still started over
# SSH (admin network) until qrexec-like RPCs exist. Test companion to vm-run,
# whose wprs path it replaces once it works.
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

    sock="/run/nox-relay/$VM-wprs.sock"
    if [ ! -S "$sock" ]; then
      echo "vm-gui: $sock missing (does $VM run wprsd, is nox-relay-$VM up?)" >&2
      exit 1
    fi

    run="''${XDG_RUNTIME_DIR:-/tmp}"
    pidfile="$run/wprsc-vchan-$VM.pid"
    if ! { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }; then
      setsid ${pkgs.wprs}/bin/wprsc --socket="$sock" \
        --control-socket="$run/wprsc-vchan-$VM-ctrl.sock" \
        >"$run/wprsc-vchan-$VM.log" 2>&1 &
      echo $! >"$pidfile"
      sleep 1
    fi

    # Same environment the wprs launcher sets for remote apps
    exec ${pkgs.openssh}/bin/ssh -i "$HOME/.ssh/$VM-vm" \
      -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
      "user@$IP" env WAYLAND_DISPLAY=wprs-0 DISPLAY=:100 XDG_SESSION_TYPE=wayland \
      PULSE_SERVER=unix:/tmp/wprs-pulse "XCURSOR_SIZE=''${XCURSOR_SIZE:-24}" \
      "$(printf '%q ' "$@")"
  '';
in
{
  home.packages = [ vmGui ];
}
