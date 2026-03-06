{ pkgs, ... }:
pkgs.writeShellScriptBin "remote-zellij" ''
  #!/usr/bin/env bash

  if [ $# -lt 1 ]; then
    echo "Usage: remote-zellij <vm-name-or-short>"
    exit 1
  fi

  VMNAME="$1"

  # Use "vm" helper to execute commands on the VM via ssh
  run_on_vm() {
    local cmd="$1"
    shift || true
    vm "$VMNAME" "$cmd" "$@"
  }

  # List sessions via ssh and clean up ANSI escapes
  ZJ_SESSIONS="$(run_on_vm "zellij" list-sessions \
    | sed -r 's/\x1B\[[0-9;]*[mK]//g' \
    | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z][^ ]*/) {print $i; break}}')"
  NO_SESSIONS="$(echo "''${ZJ_SESSIONS}" | wc -l)"

  if [ "''${NO_SESSIONS}" -ge 2 ]; then
    CHOICE=$( (echo "''${ZJ_SESSIONS}"; echo "[Start new session]") | fzf )
    if [ "''${CHOICE}" = "[Start new session]" ]; then
      run_on_vm "zellij" --layout /home/user/.config/zellij/layouts/tabs.kdl
    elif [ -n "''${CHOICE}" ]; then
      run_on_vm "zellij" attach "''${CHOICE}"
    else
      echo "Cancelled."
      exit 1
    fi
  else
    run_on_vm "zellij" --layout /home/user/.config/zellij/layouts/tabs.kdl attach -c
  fi
''

