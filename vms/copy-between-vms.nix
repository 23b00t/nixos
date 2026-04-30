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
  DRY_RUN=0

  usage() {
    echo "Usage: $0 [-m] [-n] <vm-name-or-short> <path> [path ...]" >&2
    echo "  -m                 move sources after successful transfer" >&2
    echo "  -n                 dry-run (print actions, do not transfer or delete)" >&2
    echo "  VM_COPY_KEY_PATH    optional override for transfer SSH key" >&2
    echo "  VM_COPY_USER        optional override for transfer SSH user" >&2
    exit 1
  }

  while getopts ":mnh" opt; do
    case "$opt" in
      m) MOVE=1 ;;
      n) DRY_RUN=1 ;;
      h) usage ;;
      \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ $# -lt 2 ]; then
    usage
  fi

  TARGET="$1"
  shift
  SOURCES=("$@")

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

  for src in "''${SOURCES[@]}"; do
    if [ ! -e "$src" ]; then
      echo "File or directory '$src' not found." >&2
      exit 4
    fi
  done

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

  NEED_RECURSIVE=0
  for src in "''${SOURCES[@]}"; do
    if [ -d "$src" ]; then
      NEED_RECURSIVE=1
      break
    fi
  done

  if [ $DRY_RUN -eq 1 ]; then
    echo "Target VM: $TARGET_NAME ($IP)"
    echo "Remote user: $DEFAULT_USER"
    echo "Remote dir: $REMOTE_DIR"
    echo "Sources:"
    for src in "''${SOURCES[@]}"; do
      echo "  - $src"
    done

    if [ $NEED_RECURSIVE -eq 1 ]; then
      echo "[dry-run] Would run: scp [ssh-opts] -r -- <sources...> $DEFAULT_USER@$IP:$REMOTE_DIR"
    else
      echo "[dry-run] Would run: scp [ssh-opts] -- <sources...> $DEFAULT_USER@$IP:$REMOTE_DIR"
    fi

    if [ $MOVE -eq 1 ]; then
      echo "[dry-run] Would remove local sources after successful transfer."
    fi

    echo "[dry-run] No changes were made."
    exit 0
  fi

  if [ $NEED_RECURSIVE -eq 1 ]; then
    scp "''${SSH_OPTS[@]}" -r -- "''${SOURCES[@]}" "$DEFAULT_USER@$IP:$REMOTE_DIR"
  else
    scp "''${SSH_OPTS[@]}" -- "''${SOURCES[@]}" "$DEFAULT_USER@$IP:$REMOTE_DIR"
  fi

  if [ $MOVE -eq 1 ]; then
    rm -rf -- "''${SOURCES[@]}"
  fi

  echo "Transfer to $TARGET_NAME ($IP) completed."
''

