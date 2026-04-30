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

  vmScript = pkgs.writeShellScriptBin "vm" ''
    #!/usr/bin/env bash
    set -eu

    USE_KITTEN=0

    usage() {
      echo "Usage: vm [-k] <vm-name-or-short>" >&2
      echo "Available VMs:" >&2
      cat <<EOF >&2
${vmList}
EOF
      exit 1
    }

    while getopts ":kh" opt; do
      case "$opt" in
        k) USE_KITTEN=1 ;;
        h) usage ;;
        \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
      esac
    done
    shift $((OPTIND - 1))

    if [ $# -ne 1 ]; then
      usage
    fi

    NAME="$1"

    case "$NAME" in
${vmCases}
      *)
        echo "Error: Unknown VM '$NAME'" >&2
        exit 1
        ;;
    esac

    KEY="$HOME/.ssh/$FULL_NAME-vm"

    if [ "$USE_KITTEN" -eq 1 ]; then
      exec kitten ssh -i "$KEY" "$VM_USER@$IP" -t
    else
      exec ssh -i "$KEY" "$VM_USER@$IP" -t
    fi
  '';
in
{
  home.packages = [ vmScript ];
}

