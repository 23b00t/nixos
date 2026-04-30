{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  vmScriptLib = import ./vm-script-lib.nix { };

  hostTable = vmScriptLib.hostTable {
    vms = vmRegistry.vms;
    includeUser = true;
  };

  vmNames = builtins.concatStringsSep " " (map (vm: vm.name) vmRegistry.vms);
in
pkgs.writeShellScriptBin "backup" ''
  #!/usr/bin/env bash
  set -eu

  HOSTTABLE="${hostTable}"
  ALL_VM_NAMES="${vmNames}"

  usage() {
    echo "Usage: $0 destination target-host-name [next-target ...]" >&2
    echo "   or: $0 -a destination                 (backup all VMs)" >&2
    echo "   or: $0 -r source-dir                  (restore backups)" >&2
    exit 1
  }

  resolve_target() {
    local target="$1"
    local line

    line=$(printf '%s\n' "$HOSTTABLE" | awk -v t="$target" '$1 == t { print; exit }')
    if [ -z "$line" ]; then
      return 1
    fi

    set -- $line
    RESOLVED_HOSTNAME="$1"
    RESOLVED_IP="$2"
    RESOLVED_USER="$3"
    return 0
  }

  ensure_vm_online() {
    local vm_name="$1"
    local ip="$2"
    local service="microvm@$vm_name.service"

    if ! systemctl is-active --quiet "$service"; then
      ${pkgs.libnotify}/bin/notify-send "Starting VM: $vm_name" "Please wait..."
      systemctl start "$service"

      local max_retries=30
      local count=0
      while ! ping -c 1 -W 1 "$ip" >/dev/null 2>&1; do
        sleep 1
        count=$((count+1))
        if [ $count -ge $max_retries ]; then
          ${pkgs.libnotify}/bin/notify-send "Error" "VM $vm_name failed to start network."
          return 1
        fi
      done
      sleep 2
    fi
  }

  restore() {
    local dir target logfile rsync_rsh

    for dir in "$SOURCE"/*; do
      [ -d "$dir" ] || continue

      target="$(basename "$dir")"
      if ! resolve_target "$target"; then
        continue
      fi

      if ! ensure_vm_online "$RESOLVED_HOSTNAME" "$RESOLVED_IP"; then
        continue
      fi

      echo "Restoring backup to $target ($RESOLVED_IP)..."
      logfile="$SOURCE/restore-errors-$target.log"
      rsync_rsh="ssh -i \"$HOME/.ssh/$RESOLVED_HOSTNAME-vm\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

      rsync -a --update --no-group --no-owner --numeric-ids -e "$rsync_rsh" \
        --info=progress2 \
        --log-file="$logfile" \
        "$dir/home/$RESOLVED_USER/" "$RESOLVED_USER@$RESOLVED_IP:/home/$RESOLVED_USER/"

      echo "Restore to $target ($RESOLVED_IP) completed."

      if grep -qE '^(rsync:|rsync error:|ERROR|failed|IO error)' "$logfile"; then
        echo "Errors during restore to $target:"
        grep -E '^(rsync:|rsync error:|ERROR|failed|IO error)' "$logfile"
      fi
    done
  }

  backup_host() {
    local target="$1"
    local logfile rsync_rsh

    if ! resolve_target "$target"; then
      echo "Host '$target' not found in host table." >&2
      return 3
    fi

    if ! ensure_vm_online "$RESOLVED_HOSTNAME" "$RESOLVED_IP"; then
      return 1
    fi

    echo "Starting backup of $target ($RESOLVED_IP)..."
    logfile="$DESTINATION/backup-errors-$target.log"
    mkdir -p "$DESTINATION/$target"

    rsync_rsh="ssh -i \"$HOME/.ssh/$RESOLVED_HOSTNAME-vm\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

    rsync -a --delete --no-group --no-owner --numeric-ids --relative -e "$rsync_rsh" \
      --info=progress2 \
      --log-file="$logfile" \
      "$RESOLVED_USER@$RESOLVED_IP:/home/$RESOLVED_USER/" "$DESTINATION/$target/"

    echo "Backup of $target ($RESOLVED_IP) completed."

    if grep -qE '^(rsync:|rsync error:|ERROR|failed|IO error)' "$logfile"; then
      echo "Errors of $target:"
      grep -E '^(rsync:|rsync error:|ERROR|failed|IO error)' "$logfile"
    fi
  }

  RESTORE=false
  ALL=false
  DESTINATION=""
  SOURCE=""

  while getopts ":ar:h" opt; do
    case "$opt" in
      a) ALL=true ;;
      r) RESTORE=true; SOURCE="$OPTARG" ;;
      h) usage ;;
      :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
      \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ "$RESTORE" = true ]; then
    if [ -z "$SOURCE" ]; then
      usage
    fi
    restore
    exit 0
  fi

  if [ "$ALL" = true ]; then
    if [ $# -lt 1 ]; then
      usage
    fi
    DESTINATION="$1"
    shift
    TARGETS=( $ALL_VM_NAMES )
  else
    if [ $# -lt 2 ]; then
      usage
    fi
    DESTINATION="$1"
    shift
    TARGETS=("$@")
  fi

  for TARGET in "''${TARGETS[@]}"; do
    backup_host "$TARGET"
  done
''

