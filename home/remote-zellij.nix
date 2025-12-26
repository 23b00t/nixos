{ pkgs, ... }:
pkgs.writeShellScriptBin "remote-zellij" ''
  #!/usr/bin/env bash

  if [ $# -lt 2 ]; then
    echo "Usage: remote-zellij <ip-suffix> <vm-name>"
    exit 1
  fi

  IPSUFFIX="$1"
  VMNAME="$2"

  ZJ_SESSIONS="$(vm-run -c "''${IPSUFFIX}" "''${VMNAME}" zellij list-sessions \
    | sed -r 's/\x1B\[[0-9;]*[mK]//g' \
    | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z][^ ]*/) {print $i; break}}')"
  NO_SESSIONS="$(echo "''${ZJ_SESSIONS}" | wc -l)"

  if [ "''${NO_SESSIONS}" -ge 2 ]; then
    CHOICE=$( (echo "''${ZJ_SESSIONS}"; echo "[Start new session]") | fzf )
    if [ "''${CHOICE}" = "[Start new session]" ]; then
      vm-run -c "''${IPSUFFIX}" "''${VMNAME}" zellij --layout /home/user/.config/zellij/layouts/tabs.kdl
    elif [ -n "''${CHOICE}" ]; then
      vm-run -c "''${IPSUFFIX}" "''${VMNAME}" zellij attach "''${CHOICE}"
    else
      echo "Cancelled."
      exit 1
    fi
  else
    vm-run -c "''${IPSUFFIX}" "''${VMNAME}" zellij --layout /home/user/.config/zellij/layouts/tabs.kdl attach -c
  fi
''
