{ pkgs, ... }:
pkgs.writeShellScriptBin "remote-zellij" ''
  #!/usr/bin/env bash
  set -eu

  EXTRA_SSH_ARGS=()

  usage() {
    echo "Usage: remote-zellij [-e <ssh-arg>]... <vm-name-or-short>" >&2
    exit 1
  }

  while getopts ":e:h" opt; do
    case "$opt" in
      e) EXTRA_SSH_ARGS+=("$OPTARG") ;;
      h) usage ;;
      :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
      \?) echo "Unknown option: -$OPTARG" >&2; usage ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ $# -lt 1 ]; then
    usage
  fi

  VMNAME="$1"

  VM_USER="$(vm-run -u "$VMNAME")"
  LAYOUT_PATH="/home/$VM_USER/.config/zellij/layouts/tabs.kdl"

  VM_RUN_SSH_ARGS=()
  for ssh_arg in "''${EXTRA_SSH_ARGS[@]}"; do
    VM_RUN_SSH_ARGS+=("-e" "$ssh_arg")
  done

  ZJ_SESSIONS="$(
    vm-run -c "''${VM_RUN_SSH_ARGS[@]}" "$VMNAME" zellij list-sessions \
      | sed -r 's/\x1B\[[0-9;]*[mK]//g' \
      | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z][^ ]*/) {print $i; break}}'
  )"
  NO_SESSIONS="$(printf '%s\n' "$ZJ_SESSIONS" | sed '/^$/d' | wc -l)"

  if [ "$NO_SESSIONS" -ge 2 ]; then
    CHOICE=$( (printf '%s\n' "$ZJ_SESSIONS"; echo "[Start new session]") | fzf )
    if [ "$CHOICE" = "[Start new session]" ]; then
      vm-run -c "''${VM_RUN_SSH_ARGS[@]}" "$VMNAME" zellij --layout "$LAYOUT_PATH"
    elif [ -n "$CHOICE" ]; then
      vm-run -c "''${VM_RUN_SSH_ARGS[@]}" "$VMNAME" zellij attach "$CHOICE"
    else
      echo "Cancelled."
      exit 1
    fi
  else
    vm-run -c "''${VM_RUN_SSH_ARGS[@]}" "$VMNAME" zellij --layout "$LAYOUT_PATH" attach -c
  fi
''

