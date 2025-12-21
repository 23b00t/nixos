{
  pkgs ? import <nixpkgs> { },
}:
pkgs.writeShellScriptBin "cp-vm" ''
  # cp-vm: Copy or move a file/folder via rsync to a target VM or host using a host table.
  #
  # Syntax:
  #   cp-vm [-m] target-host-name ./filename
  #     -m               : move (instead of copy)
  #     target-host-name : destination host, as defined in the 'vm-hosts' table
  #     ./filename       : file or directory to transfer (relative or absolute path)
  #
  # The 'vm-hosts' file must exist in the same directory as this script and contains entries in the format:
  #     <hostname> <ip> [username]
  #
  # Example for vm-hosts:
  #   vma 10.0.0.1
  #   host 10.0.0.0 another-username
  #
  # If username is omitted, the default is 'user'.

  set -e

  DEFAULT_USER="user"

  # Host table: <hostname> <ip> [username]
  HOSTTABLE='
  host 192.168.178.200 nx
  nvim 10.0.0.1
  chat 10.0.0.2
  music 10.0.0.4
  net 10.0.0.5
  net-private 10.0.0.6
  wine 10.0.0.7
  kali 10.0.0.8
  office 10.0.0.9
  vault 10.0.0.10
  irc 10.0.0.11
  '

  usage() {
    echo "Usage: $0 [-m] target-host-name ./filename"
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

  RSYNC_OPTS="-av"
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
