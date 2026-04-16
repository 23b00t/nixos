{ pkgs, lib, inputs }:
let
  vmRegistry = import ../../vms/registry.nix;

  # Build a simple host table with both long and short names mapped to IPs.
  hostTable = builtins.concatStringsSep "\n" (map (vm:
    let
      base = "${vm.name} ${vm.ip}";
    in
      if vm.short != null && vm.short != vm.name then
        base + "\n" + "${vm.short} ${vm.ip}"
      else
        base
  ) vmRegistry.vms);

in
  pkgs.writeShellScriptBin "backup" ''
  set -e

  HOSTTABLE="${hostTable}"

  usage() {
    echo "Usage: $0 destination target-host-name next-target ..."
    echo "or: $0 -a destination (to backup all targets in the list)"
    echo "or: $0 -r source-dir (to restore backups from source-dir)"
    exit 1
  }

  restore() {
    # Iterate over all directories in SOURCE
    for DIR in $(find "$SOURCE" -mindepth 1 -maxdepth 1 -type d); do
      TARGET=$(basename "$DIR")
      # Check if TARGET exists in HOSTTABLE
      LINE=$(echo "$HOSTTABLE" | grep -E "^$TARGET[[:space:]]+" || true)
      if [ -n "$LINE" ]; then
        set -- $LINE
        HOSTNAME="$1"
        IP="$2"
        VM_NAME="$HOSTNAME"
        SERVICE="microvm@$VM_NAME.service"

        # Start VM if not running
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
              continue
            fi
          done
          sleep 2
        fi

        echo "Restoring backup to $TARGET ($IP)..."
        LOGFILE="$SOURCE/restore-errors-$TARGET.log"
        rsync -a --update --no-group --no-owner --numeric-ids -e ssh \
          --info=progress2 \
          --log-file="$LOGFILE" \
          "$DIR/home/user/" "user@$IP:/home/user/"
        RSYNC_STATUS=$?
        echo "Restore to $TARGET ($IP) completed with status $RSYNC_STATUS."

        # Print errors
        if grep -qE '^(rsync:|rsync error:|ERROR|failed|IO error)' "$LOGFILE"; then
          echo "Errors during restore to $TARGET:"
          grep -E '^(rsync:|rsync error:|ERROR|failed|IO error)' "$LOGFILE"
        fi
      fi
    done
    exit 0
  }

  backup_host() {
    TARGET="$1"
    LINE=$(echo "$HOSTTABLE" | grep -E "^[[:space:]]*$TARGET[[:space:]]+" || true)
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
    rsync -a --delete --no-group --no-owner --numeric-ids --relative -e ssh \
      --info=progress2 \
      --log-file="$LOGFILE" \
      "user@$IP:/home/user/" "$DESTINATION/$TARGET/"
    RSYNC_STATUS=$?
    echo "Backup of $TARGET ($IP) completed with status $RSYNC_STATUS."

    if grep -qE '^(rsync:|rsync error:|ERROR|failed|IO error)' "$LOGFILE"; then
      echo "Errors of $TARGET:"
      grep -E '^(rsync:|rsync error:|ERROR|failed|IO error)' "$LOGFILE"
    fi
  }

  RESTORE=false
  ALL=false
  DESTINATION=""
  SOURCE=""
  TARGETS=()

  while getopts ":ar:" opt; do
    case $opt in
      a)
        ALL=true
        ;;
      r)
        RESTORE=true
        SOURCE="$OPTARG"
        ;;
      \?)
        usage
        ;;
    esac
  done
  shift $((OPTIND -1))

  if [ "$RESTORE" = true ]; then
    if [ -z "$SOURCE" ]; then
      usage
    fi
    restore
    exit 0
  fi

  if [ "$ALL" = true ]; then
    DESTINATION="$1"
    shift
    TARGETS=($(echo "$HOSTTABLE" | awk '{print $1}'))
  else
    if [ $# -lt 2 ]; then
      usage
    fi
    DESTINATION="$1"
    shift
    TARGETS=("$@")
  fi

  for TARGET in ''${TARGETS[@]}; do
    backup_host "$TARGET"
  done
''
