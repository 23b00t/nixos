{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  vmScriptLib = import ./vm-script-lib.nix { };

  vmCases = vmScriptLib.vmCaseBlock {
    vms = vmRegistry.vms;
    assignments = [
      {
        shellName = "IP";
        attr = "ip";
      }
      {
        shellName = "FULL_NAME";
        attr = "name";
      }
      {
        shellName = "VM_USER";
        valueFrom = vmScriptLib.vmUser;
      }
    ];
  };

  vmList = vmScriptLib.vmList vmRegistry.vms;

  vmRunner = pkgs.writeShellScriptBin "vm-run" ''
    #!/usr/bin/env bash
    set -eu

    CLI_MODE=0
    PRINT_USER=0
    EXTRA_SSH_ARGS=()

    usage() {
      echo "Usage: vm-run [-c] [-u] [-e <ssh-arg>]... <vm-name-or-short> <binary> [args...]" >&2
      echo "       vm-run -u <vm-name-or-short>" >&2
      echo "Example: vm-run -c -e -J -e jump-host net bash" >&2
      echo "Available VMs:" >&2
      cat <<EOF >&2
${vmList}
EOF
      exit 1
    }

    while getopts ":cue:h" opt; do
      case "$opt" in
        c) CLI_MODE=1 ;;
        u) PRINT_USER=1 ;;
        e) EXTRA_SSH_ARGS+=("$OPTARG") ;;
        h) usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
        \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
      esac
    done
    shift $((OPTIND -1))

    if [ $# -lt 1 ]; then
      usage
    fi

    VM_KEY="$1"
    shift

    case "$VM_KEY" in
${vmCases}
      *)
        echo "Error: Unknown VM '$VM_KEY'" >&2
        exit 1
        ;;
    esac

    if [ "$PRINT_USER" -eq 1 ]; then
      echo "$VM_USER"
      exit 0
    fi

    if [ $# -lt 1 ]; then
      usage
    fi

    BINARY="$1"
    shift

    KEY="$HOME/.ssh/$FULL_NAME-vm"
    SERVICE="microvm@$FULL_NAME.service"

    if ! systemctl is-active --quiet "$SERVICE"; then
      ${pkgs.libnotify}/bin/notify-send "Starting VM: $FULL_NAME" "Please wait..."
      systemctl start "$SERVICE"
      MAX_RETRIES=30
      COUNT=0
      while ! ping -c 1 -W 1 "$IP" >/dev/null 2>&1; do
        sleep 1
        COUNT=$((COUNT+1))
        if [ $COUNT -ge $MAX_RETRIES ]; then
          ${pkgs.libnotify}/bin/notify-send "Error" "VM $FULL_NAME failed to start network."
          exit 1
        fi
      done
      sleep 2
    fi

    if [ "$CLI_MODE" -eq 1 ]; then
      exec ssh -i "$KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "''${EXTRA_SSH_ARGS[@]}" "$VM_USER@$IP" -t -- "$BINARY" "$@"
    else
      wprs "$IP" run -- "$BINARY" "$@" &
      WPRS_PID=$!
      wait $WPRS_PID
      pkill -P $WPRS_PID ssh || true
    fi
  '';
in
{
  home.packages = [ vmRunner ];
}
