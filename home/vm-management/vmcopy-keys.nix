{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  vmScriptLib = import ./vm-script-lib.nix { };

  vmCases = vmScriptLib.vmCaseBlock {
    vms = vmRegistry.vmCopyParticipants;
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

  vmList = vmScriptLib.vmList vmRegistry.vmCopyParticipants;
in
pkgs.writeShellScriptBin "vmcopy-keys" ''
  #!/usr/bin/env bash
  set -eu

  usage() {
    echo "Usage: $0 <vm-name-or-short> [...]" >&2
    echo "Available transfer-capable VMs:" >&2
    cat <<EOF >&2
${vmList}
EOF
    exit 1
  }

  while getopts ":h" opt; do
    case "$opt" in
      h) usage ;;
      \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ $# -lt 1 ]; then
    usage
  fi

  if ${pkgs.git}/bin/git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT="$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
  else
    REPO_ROOT="$HOME/nixos-config"
  fi

  if [ ! -f "$REPO_ROOT/flake.nix" ]; then
    echo "Could not determine repository root. Run from the repo or adjust REPO_ROOT in the script." >&2
    exit 2
  fi

  KEY_DIR="$REPO_ROOT/vms/vmcopy-keys"
  ${pkgs.coreutils}/bin/mkdir -p "$KEY_DIR"

  for NAME in "$@"; do
    case "$NAME" in
${vmCases}
      *)
        echo "Error: Unknown or non-transfer VM '$NAME'" >&2
        exit 3
        ;;
    esac

    SSH_KEY="$HOME/.ssh/$FULL_NAME-vm"
    if [ ! -r "$SSH_KEY" ]; then
      echo "Admin SSH key not found for '$FULL_NAME' at '$SSH_KEY'." >&2
      exit 4
    fi

    echo "Ensuring vmcopy keypair exists in '$FULL_NAME'..."
    PUB_KEY="$(${pkgs.openssh}/bin/ssh \
      -i "$SSH_KEY" \
      -o IdentitiesOnly=yes \
      -o StrictHostKeyChecking=accept-new \
      "$VM_USER@$IP" \
      'set -eu
       mkdir -p ~/.ssh
       chmod 700 ~/.ssh
       if [ ! -f ~/.ssh/vmcopy ]; then
         ssh-keygen -t ed25519 -f ~/.ssh/vmcopy -N "" -C "$(hostname)-vmcopy" >/dev/null
       fi
       chmod 600 ~/.ssh/vmcopy
       chmod 644 ~/.ssh/vmcopy.pub
       cat ~/.ssh/vmcopy.pub')"

    if [ -z "$PUB_KEY" ]; then
      echo "Failed to read vmcopy public key from '$FULL_NAME'." >&2
      exit 5
    fi

    printf '%s\n' "$PUB_KEY" > "$KEY_DIR/$FULL_NAME.pub"
    echo "Wrote $KEY_DIR/$FULL_NAME.pub"
  done

  echo "Done. Review and commit the updated public key files under vms/vmcopy-keys/."
''

