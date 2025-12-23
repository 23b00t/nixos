{
  pkgs ? import <nixpkgs> { },
}:
pkgs.writeShellScriptBin "backup" ''
    set -e

    # Host table: <hostname> <ip>
    HOSTTABLE='
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
      echo "Usage: $0 destination target-host-name next-target ..."
      echo "Or: $0 -a destination (to backup all targets in the list)"
      exit 1
    }

  if [ "$1" = "-a" ]; then
    shift
    DESTINATION="$1"
    shift
    TARGETS=$(echo "$HOSTTABLE" | awk '{print $1}')
  else
    if [ $# -lt 2 ]; then
      usage
    fi
    DESTINATION="$1"
    shift
    TARGETS="$@"
  fi

  backup_host() {
    TARGET="$1"
    LINE=$(echo "$HOSTTABLE" | grep -E "^$TARGET[[:space:]]+" || true)
    if [ -z "$LINE" ]; then
      echo "Host '$TARGET' not found in host table." >&2
      return 3
    fi

    set -- $LINE
    HOSTNAME="$1"
    IP="$2"
    if [ -z "$IP" ]; then
      echo "Malformed host table entry for '$TARGET'." >&2
      return 5
    fi

    VM_NAME="$HOSTNAME"
    SERVICE="microvm@$VM_NAME.service"

    if ! systemctl is-active --quiet "$SERVICE"; then
      ${pkgs.libnotify}/bin/notify-send "Starting VM: $VM_NAME" "Please wait..."
      systemctl start "$SERVICE"
      MAX_RETRIES=30
      COUNT=0
      while ! ping -c 1 -W 1 "$IP" &> /dev/null; do
        sleep 1
        COUNT=$((COUNT+1))
        if [ $COUNT -ge $MAX_RETRIES ]; then
          ${pkgs.libnotify}/bin/notify-send "Error" "VM $VM_NAME failed to start network."
          return 1
        fi
      done
      sleep 2
    fi

    echo "Starting backup of $TARGET ($IP)..."
    LOGFILE="$DESTINATION/backup-errors-$TARGET.log"
    mkdir -p "$DESTINATION/$TARGET"
    rsync -a --delete --numeric-ids --relative -e ssh \
      --info=progress2 \
      --log-file="$LOGFILE" \
      "user@$IP:/home/user/" "$DESTINATION/$TARGET/"
    RSYNC_STATUS=$?
    echo "Backup of $TARGET ($IP) completed with status $RSYNC_STATUS."

    if grep -qE 'rsync error|error|failed|IO error' "$LOGFILE"; then
      echo "Fehlerhafte Dateien beim Backup von $TARGET:"
      grep -E 'rsync error|error|failed|IO error' "$LOGFILE"
    fi
  }

  for TARGET in $TARGETS; do
    backup_host "$TARGET"
  done
''
