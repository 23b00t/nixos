{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  vmNames = builtins.concatStringsSep " " (map (vm: vm.name) vmRegistry.vms);
  # name=group pairs for VMs with a shared store image (registry `storeGroup`)
  vmGroups = builtins.concatStringsSep " " (
    map (vm: "[${vm.name}]=${vm.storeGroup}") (
      builtins.filter (vm: (vm.storeGroup or null) != null) vmRegistry.vms
    )
  );
in
pkgs.writeShellScriptBin "manage-vms" ''
  #!/usr/bin/env bash
  set -eu

  ALL_VMS=( ${vmNames} )
  declare -A STORE_GROUP=( ${vmGroups} )
  STATE_DIR=/var/lib/microvms
  RUNNING_ONLY=0
  STALE_ONLY=0
  GROUP=""

  usage() {
    cat <<EOF >&2
Usage:
  manage-vms status [--running] [--group <group>] [--stale]
  manage-vms <start|stop|restart|reload> [--running] [--group <group>] [--stale]

  --group <group>  only VMs of this store group (registry storeGroup)
  --stale          only running VMs whose store image differs from the
                   current one (e.g. after a group update)

Examples:
  manage-vms status
  manage-vms status --running
  manage-vms restart --running
  manage-vms restart --stale
  manage-vms restart --group desktop
EOF
    exit 1
  }

  # Store image a runner boots from ("-" if it has none, e.g. virtiofs store)
  store_image() {
    local runner="$1"
    [ -e "$runner" ] || { echo "-"; return; }
    nix-store -qR "$runner" 2>/dev/null | grep -m1 -- '-microvm-store-disk\.' || echo "-"
  }

  # ok | stale | - (not running or no store image)
  image_state() {
    local vm="$1" booted current
    [ -e "$STATE_DIR/$vm/booted" ] || { echo "-"; return; }
    booted="$(store_image "$STATE_DIR/$vm/booted")"
    current="$(store_image "$STATE_DIR/$vm/current")"
    if [ "$booted" = "-" ]; then
      echo "-"
    elif [ "$booted" = "$current" ]; then
      echo "ok"
    else
      echo "stale"
    fi
  }

  resolve_targets() {
    local vm candidates=()
    TARGETS=()

    if [ "$RUNNING_ONLY" -eq 1 ]; then
      while IFS= read -r unit; do
        [ -n "$unit" ] || continue
        vm="''${unit#microvm@}"
        vm="''${vm%.service}"
        candidates+=("$vm")
      done < <(systemctl list-units --type=service --state=running --no-legend --no-pager 'microvm@*.service' | awk '{print $1}')
    else
      candidates=("''${ALL_VMS[@]}")
    fi

    for vm in "''${candidates[@]}"; do
      if [ -n "$GROUP" ] && [ "''${STORE_GROUP[$vm]:-}" != "$GROUP" ]; then
        continue
      fi
      if [ "$STALE_ONLY" -eq 1 ] && [ "$(image_state "$vm")" != "stale" ]; then
        continue
      fi
      TARGETS+=("$vm")
    done
  }

  print_status_table() {
    local vm unit active substate enabled

    printf "%-14s %-10s %-12s %-10s %-9s %-6s\n" "VM" "ACTIVE" "SUBSTATE" "ENABLED" "GROUP" "IMAGE"
    printf "%-14s %-10s %-12s %-10s %-9s %-6s\n" "--------------" "----------" "------------" "----------" "---------" "------"

    for vm in "''${TARGETS[@]}"; do
      unit="microvm@$vm.service"

      active="$(systemctl is-active "$unit" 2>/dev/null || true)"
      [ -n "$active" ] || active="not-found"

      substate="$(systemctl show "$unit" -P SubState 2>/dev/null || true)"
      [ -n "$substate" ] || substate="-"

      enabled="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
      [ -n "$enabled" ] || enabled="-"

      printf "%-14s %-10s %-12s %-10s %-9s %-6s\n" "$vm" "$active" "$substate" "$enabled" \
        "''${STORE_GROUP[$vm]:--}" "$(image_state "$vm")"
    done
  }

  run_action() {
    local action="$1"
    local vm unit

    for vm in "''${TARGETS[@]}"; do
      unit="microvm@$vm.service"
      echo "sudo systemctl $action $unit"
      sudo systemctl "$action" "$unit"
    done
  }

  [ $# -ge 1 ] || usage

  COMMAND="$1"
  shift

  while [ $# -gt 0 ]; do
    case "$1" in
      --running)
        RUNNING_ONLY=1
        ;;
      --stale)
        STALE_ONLY=1
        ;;
      --group)
        [ $# -ge 2 ] || usage
        GROUP="$2"
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        ;;
    esac
    shift
  done

  resolve_targets

  if [ "''${#TARGETS[@]}" -eq 0 ]; then
    echo "No matching VMs found."
    exit 0
  fi

  case "$COMMAND" in
    status)
      print_status_table
      ;;
    start|stop|restart|reload)
      run_action "$COMMAND"
      ;;
    *)
      echo "Unsupported command: $COMMAND" >&2
      usage
      ;;
  esac
''
