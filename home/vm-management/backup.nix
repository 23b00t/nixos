{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  vmScriptLib = import ./vm-script-lib.nix { };

  hostTable = vmScriptLib.hostTable {
    vms = vmRegistry.vms;
    includeUser = true;
  };

  vmNames = builtins.concatStringsSep " " (
    map (vm: vm.name) (builtins.filter (vm: vm.name != "steam") vmRegistry.vms)
  );
in
pkgs.writeShellScriptBin "backup" ''
  #!/usr/bin/env bash
  set -eu

  HOSTTABLE="${hostTable}"
  ALL_VM_NAMES="${vmNames}"
  REMOTE_RSYNC="sudo -n ${pkgs.rsync}/bin/rsync"

  SUCCESS_COUNT=0
  FAIL_COUNT=0

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

    ENSURE_STARTED_BY_SCRIPT=0

    if ! systemctl is-active --quiet "$service"; then
      ${pkgs.libnotify}/bin/notify-send "Starting VM: $vm_name" "Please wait..."
      systemctl start "$service"
      ENSURE_STARTED_BY_SCRIPT=1
    fi

    local max_retries=30
    local count=0
    while ! ping -c 1 -W 1 "$ip" >/dev/null 2>&1; do
      sleep 1
      count=$((count+1))
      if [ $count -ge $max_retries ]; then
        ${pkgs.libnotify}/bin/notify-send "Error" "VM $vm_name failed to start network."
        if [ "$ENSURE_STARTED_BY_SCRIPT" -eq 1 ]; then
          systemctl stop "$service" >/dev/null 2>&1 || true
        fi
        return 1
      fi
    done

    return 0
  }

  stop_vm_if_started_by_script() {
    local vm_name="$1"
    local started_by_script="$2"
    local service="microvm@$vm_name.service"

    if [ "$started_by_script" -eq 1 ]; then
      if ! systemctl stop "$service" >/dev/null 2>&1; then
        echo "[warn] Could not stop VM '$vm_name' after operation." >&2
      fi
    fi
  }

  restore() {
    local dir target started_by_script logfile rsync_rsh
    local fail_log_dir="$SOURCE/.restore-failures"

    mkdir -p "$fail_log_dir"

    for dir in "$SOURCE"/*; do
      [ -d "$dir" ] || continue

      target="$(basename "$dir")"
      if ! resolve_target "$target"; then
        echo "[restore][error] Unknown target directory '$target' (not in VM registry)." >&2
        FAIL_COUNT=$((FAIL_COUNT+1))
        continue
      fi

      if ! ensure_vm_online "$RESOLVED_HOSTNAME" "$RESOLVED_IP"; then
        echo "[restore][error] VM '$target' is not reachable." >&2
        FAIL_COUNT=$((FAIL_COUNT+1))
        continue
      fi

      started_by_script="$ENSURE_STARTED_BY_SCRIPT"
      logfile="$fail_log_dir/restore-$target.log"
      rsync_rsh="ssh -i \"$HOME/.ssh/$RESOLVED_HOSTNAME-vm\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

      if ${pkgs.rsync}/bin/rsync -aHAX --update --numeric-ids --rsync-path="$REMOTE_RSYNC" -e "$rsync_rsh" \
        "$dir/home/$RESOLVED_USER/" "$RESOLVED_USER@$RESOLVED_IP:/home/$RESOLVED_USER/" \
        >"$logfile" 2>&1; then
        rm -f "$logfile"
        SUCCESS_COUNT=$((SUCCESS_COUNT+1))
      else
        echo "[restore][error] '$target' failed. See: $logfile" >&2
        FAIL_COUNT=$((FAIL_COUNT+1))
      fi

      stop_vm_if_started_by_script "$RESOLVED_HOSTNAME" "$started_by_script"
    done
  }

  backup_host() {
    local target="$1"
    local started_by_script logfile rsync_rsh
    local fail_log_dir="$DESTINATION/.backup-failures"

    if ! resolve_target "$target"; then
      echo "[backup][error] Host '$target' not found in VM registry." >&2
      FAIL_COUNT=$((FAIL_COUNT+1))
      return
    fi

    if ! ensure_vm_online "$RESOLVED_HOSTNAME" "$RESOLVED_IP"; then
      echo "[backup][error] VM '$target' is not reachable." >&2
      FAIL_COUNT=$((FAIL_COUNT+1))
      return
    fi

    started_by_script="$ENSURE_STARTED_BY_SCRIPT"

    mkdir -p "$DESTINATION/$target"
    mkdir -p "$fail_log_dir"
    logfile="$fail_log_dir/backup-$target.log"

    rsync_rsh="ssh -i \"$HOME/.ssh/$RESOLVED_HOSTNAME-vm\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

    if ${pkgs.rsync}/bin/rsync -aHAX --delete --numeric-ids --relative --rsync-path="$REMOTE_RSYNC" -e "$rsync_rsh" \
      "$RESOLVED_USER@$RESOLVED_IP:/home/$RESOLVED_USER/" "$DESTINATION/$target/" \
      >"$logfile" 2>&1; then
      rm -f "$logfile"
      SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    else
      echo "[backup][error] '$target' failed. See: $logfile" >&2
      FAIL_COUNT=$((FAIL_COUNT+1))
    fi

    stop_vm_if_started_by_script "$RESOLVED_HOSTNAME" "$started_by_script"
  }

  print_summary_and_exit() {
    local mode="$1"

    if [ "$FAIL_COUNT" -eq 0 ]; then
      echo "[$mode] success: $SUCCESS_COUNT target(s) completed without errors."
      exit 0
    fi

    echo "[$mode] failed: $FAIL_COUNT target(s), succeeded: $SUCCESS_COUNT." >&2
    exit 1
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
    print_summary_and_exit "restore"
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

  print_summary_and_exit "backup"
''

