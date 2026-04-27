{ pkgs, lib, ... }:
let
  vmRegistry = import ./registry.nix;

  # Host table: <hostname> <ip>
  # We include both long and short names for transfer-capable VMs only.
  hostTable = builtins.concatStringsSep "\n" (
    map (vm:
      let
        base = "${vm.name} ${vm.ip}";
      in
        if vm.short != null && vm.short != vm.name then
          base + "\n" + "${vm.short} ${vm.ip}"
        else
          base
    ) vmRegistry.vmCopyParticipants
  );

in
pkgs.writeShellScriptBin "cp-vm" ''
  # cp-vm: Copy or move a file/folder to another VM using the restricted vmcopy account.
  #
  # Syntax:
  #   cp-vm [-m] <vm-name-or-short> ./filename
  #     -m                : move (instead of copy)
  #     <vm-name-or-short>: destination VM, long or short name from registry
  #     ./filename        : file or directory to transfer (relative or absolute path)
  #
  # Notes:
  # - only transfer-capable VMs from the registry are valid targets
  # - uploads land below /home/user/incoming/<source-vm>/ on the target
  # - the dedicated transfer key will later be deployed automatically; for now the
  #   script expects it at $VM_COPY_KEY_PATH or /run/vmcopy/id_ed25519

  set -eu

  SELF_HOSTNAME="$(hostname)"
  SELF_VM="''${SELF_HOSTNAME%-vm}"
  DEFAULT_USER="vmcopy"
  DEFAULT_KEY_PATH="/run/vmcopy/id_ed25519"
  KEY_PATH="''${VM_COPY_KEY_PATH:-$DEFAULT_KEY_PATH}"
  HOSTTABLE="${hostTable}"

  usage() {
    echo "Usage: $0 [-m] <vm-name-or-short> ./filename" >&2
    echo "  -m                : move (instead of copy)" >&2
    echo "  VM_COPY_KEY_PATH   : optional override for the transfer SSH key" >&2
    exit 1
  }

  MOVE=0
  if [ "''${1:-}" = "-m" ]; then
    MOVE=1
    shift
  fi

  if [ $# -ne 2 ]; then
    usage
  fi

  TARGET="$1"
  FILE="$2"

  LINE=$(printf '%s\n' "$HOSTTABLE" | awk -v target="$TARGET" '$1 == target { print; exit }')
  if [ -z "$LINE" ]; then
    echo "Transfer target '$TARGET' is not allowed." >&2
    exit 3
  fi

  set -- $LINE
  TARGET_NAME="$1"
  IP="$2"

  if [ -z "$IP" ]; then
    echo "Malformed host table entry for '$TARGET'." >&2
    exit 5
  fi

  if [ ! -e "$FILE" ]; then
    echo "File or directory '$FILE' not found." >&2
    exit 4
  fi

  if [ ! -r "$KEY_PATH" ]; then
    echo "Transfer key not found at '$KEY_PATH'." >&2
    echo "Set VM_COPY_KEY_PATH to a readable temporary key until agenix is added." >&2
    exit 6
  fi

  FILE_BASENAME="$(basename "$FILE")"
  REMOTE_DIR="./$SELF_VM/"
  SSH_OPTS="-i $KEY_PATH -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

  if [ -d "$FILE" ]; then
    scp $SSH_OPTS -r -- "$FILE" "''${DEFAULT_USER}@''${IP}:$REMOTE_DIR"
  else
    scp $SSH_OPTS -- "$FILE" "''${DEFAULT_USER}@''${IP}:$REMOTE_DIR"
  fi

  if [ $MOVE -eq 1 ]; then
    rm -rf -- "$FILE"
  fi

  echo "Transfer to $TARGET_NAME ($IP) completed."
''

