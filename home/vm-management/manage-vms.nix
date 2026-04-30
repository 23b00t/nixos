{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  vmNames = builtins.concatStringsSep " " (map (vm: vm.name) vmRegistry.vms);
in
pkgs.writeShellScriptBin "manage-vms" ''
  #!/usr/bin/env bash
  set -eu

  ALL_VMS=( ${vmNames} )
  RUNNING_ONLY=0

  usage() {
    cat <<EOF >&2
Usage:
  manage-vms status [--running]
  manage-vms <start|stop|restart|reload> [--running]

Examples:
  manage-vms status
  manage-vms status --running
  manage-vms restart --running
EOF
    exit 1
  }

  resolve_targets() {
    TARGETS=()

    if [ "$RUNNING_ONLY" -eq 1 ]; then
      while IFS= read -r unit; do
        [ -n "$unit" ] || continue
        vm="''${unit#microvm@}"
        vm="''${vm%.service}"
        TARGETS+=("$vm")
      done < <(systemctl list-units --type=service --state=running --no-legend --no-pager 'microvm@*.service' | awk '{print $1}')
      return
    fi

    TARGETS=("''${ALL_VMS[@]}")
  }

  print_status_table() {
    local vm unit active substate enabled

    printf "%-14s %-10s %-12s %-10s\n" "VM" "ACTIVE" "SUBSTATE" "ENABLED"
    printf "%-14s %-10s %-12s %-10s\n" "--------------" "----------" "------------" "----------"

    for vm in "''${TARGETS[@]}"; do
      unit="microvm@$vm.service"

      active="$(systemctl is-active "$unit" 2>/dev/null || true)"
      [ -n "$active" ] || active="not-found"

      substate="$(systemctl show "$unit" -P SubState 2>/dev/null || true)"
      [ -n "$substate" ] || substate="-"

      enabled="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
      [ -n "$enabled" ] || enabled="-"

      printf "%-14s %-10s %-12s %-10s\n" "$vm" "$active" "$substate" "$enabled"
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

