{ pkgs, ... }:
pkgs.writeShellScriptBin "remote-zellij" ''
  #!/usr/bin/env bash

  if [ $# -lt 1 ]; then
    echo "Usage: remote-zellij <vm-name>"
    exit 1
  fi

  VMNAME="$1"
  shift

  EXTRA_SSH_ARGS=""

  while getopts "e:" opt; do
    case $opt in
      e) EXTRA_SSH_ARGS="$OPTARG" ;;
      *) ;;
    esac
  done
  shift $((OPTIND -1))

  ZJ_SESSIONS="$(vm-run -c "''${VMNAME}" zellij list-sessions \
    | sed -r 's/\x1B\[[0-9;]*[mK]//g' \
    | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z][^ ]*/) {print $i; break}}')"
  NO_SESSIONS="$(echo "''${ZJ_SESSIONS}" | wc -l)"

  if [ "''${NO_SESSIONS}" -ge 2 ]; then
    CHOICE=$( (echo "''${ZJ_SESSIONS}"; echo "[Start new session]") | fzf )
    if [ "''${CHOICE}" = "[Start new session]" ]; then
      vm-run -c -e "$EXTRA_SSH_ARGS" "''${VMNAME}" zellij --layout /home/user/.config/zellij/layouts/tabs.kdl
    elif [ -n "''${CHOICE}" ]; then
      vm-run -c -e "$EXTRA_SSH_ARGS" "''${VMNAME}" zellij attach "''${CHOICE}"
    else
      echo "Cancelled."
      exit 1
    fi
  else
    vm-run -c "''${VMNAME}" zellij --layout /home/user/.config/zellij/layouts/tabs.kdl attach -c
  fi
''
