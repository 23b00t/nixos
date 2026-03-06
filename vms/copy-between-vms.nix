{ pkgs, lib, ... }:
let
  vmRegistry = import ./registry.nix { inherit lib; };

  # Host table: <hostname> <ip> [username]
  # We include both long and short names; default user is 'user' except for host.
  hostTable = builtins.concatStringsSep "\n" (
    [ "host 10.0.0.254 nx" ]
    ++ (map (vm:
      let
        base = "${vm.name} ${vm.ip}";
      in
        if vm.short != null && vm.short != vm.name then
          base + "\n" + "${vm.short} ${vm.ip}"
        else
          base
    ) vmRegistry.vms)
  );

in
pkgs.writeShellScriptBin "cp-vm" ''
  # cp-vm: Copy or move a file/folder via rsync to a target VM or host using a host table.
  #
  # Syntax:
  #   cp-vm [-m] <vm-name-or-short> ./filename
  #     -m               : move (instead of copy)
  #     <vm-name-or-short>: destination VM, long or short name from registry
  #     ./filename       : file or directory to transfer (relative or absolute path)
  #
  # The host table is generated from Nix VM registry.

  set -e

  DEFAULT_USER="user"

  HOSTTABLE='''${hostTable}

  usage() {
    echo "Usage: $0 [-m] <vm-name-or-short> ./filename"
    echo "  -m               : move (instead of copy)"
    exit 1
  }

  MOVE=0
  if [ "$1" == "-m" ]; then
    MOVE=1
    shift
  fi

  if [ $# -ne 2 ]; then
    usage
  fi

  TARGET="$1"
  FILE="$2"

  # Lookup host in host table
  LINE=$(echo "$HOSTTABLE" | grep -E "^$TARGET[[:space:]]+" || true)
  if [ -z "$LINE" ]; then
    echo "Host '$TARGET' not found in host table." >&2
    exit 3
  fi

  # Parse values
  set -- $LINE
  HOSTNAME="$1"
  IP="$2"
  if [ -z "$IP" ]; then
    echo "Malformed host table entry for '$TARGET'." >&2
    exit 5
  fi
  if [ -n "$3" ]; then
    USERNAME="$3"
  else
    USERNAME="$DEFAULT_USER"
  fi

  if [ ! -e "$FILE" ]; then
    echo "File or directory '$FILE' not found." >&2
    exit 4
  fi

  RSYNC_OPTS="-a --info=progress2 --no-group --no-owner"
  RSYNC_PATH="mkdir -p ~/incoming/$(hostname) && rsync"
  DEST="''${USERNAME}@''${IP}:~/incoming/$(hostname)/"

  # Copy or move using rsync
  if [ $MOVE -eq 1 ]; then
    rsync $RSYNC_OPTS --rsync-path="$RSYNC_PATH" --remove-source-files "$FILE" "$DEST"
    # Remove empty source directories if moving
    if [ -d "$FILE" ]; then
      find "$FILE" -type d -empty -delete
    fi
  else
    rsync $RSYNC_OPTS --rsync-path="$RSYNC_PATH" "$FILE" "$DEST"
  fi

  echo "Transfer to $TARGET ($IP) completed."
''

