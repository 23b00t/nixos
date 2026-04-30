{ pkgs, ... }:
let
  vmRegistry = import ./registry.nix;

  # Host table: <hostname-or-short> <ip>
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
  #!/usr/bin/env bash
  # cp-vm: Copy or move a file/folder to another VM using the restricted vmcopy account.
  set -eu

  SELF_HOSTNAME="$(hostname)"
  SELF_VM="''${SELF_HOSTNAME%-vm}"
  DEFAULT_USER="''${VM_COPY_USER:-vmcopy}"
  DEFAULT_KEY_PATH="$HOME/.ssh/vmcopy"
  KEY_PATH="''${VM_COPY_KEY_PATH:-$DEFAULT_KEY_PATH}"
  HOSTTABLE="${hostTable}"
  MOVE=0

  usage() {
    echo "Usage: $0 [-m] <vm-name-or-short> <path>" >&2
    echo "  -m                 move source after successful transfer" >&2
    echo "  VM_COPY_KEY_PATH    optional override for transfer SSH key" >&2
    echo "  VM_COPY_USER        optional override for transfer SSH user" >&2
    exit 1
  }

  while getopts ":mh" opt; do
    case "$opt" in
      m) MOVE=1 ;;
      h) usage ;;
      \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
    esac
  done
  shift $((OPTIND - 1))

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
    exit 6
  fi

  REMOTE_DIR="./$SELF_VM/"
  SSH_OPTS=(
    -i "$KEY_PATH"
    -o IdentitiesOnly=yes
    -o StrictHostKeyChecking=accept-new
  )

  if [ -d "$FILE" ]; then
    scp "''${SSH_OPTS[@]}" -r -- "$FILE" "$DEFAULT_USER@$IP:$REMOTE_DIR"
  else
    scp "''${SSH_OPTS[@]}" -- "$FILE" "$DEFAULT_USER@$IP:$REMOTE_DIR"
  fi

  if [ $MOVE -eq 1 ]; then
    rm -rf -- "$FILE"
  fi

  echo "Transfer to $TARGET_NAME ($IP) completed."
''

