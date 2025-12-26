{ pkgs, ... }:
pkgs.writeShellScriptBin "remote-zellij" ''
  #!/usr/bin/env bash

  if [ $# -lt 2 ]; then
    echo "Usage: remote-zellij <ip-suffix> <vm-name>"
    exit 1
  fi

  ZJ_SESSIONS="$(vm-run -c "$1" "$2" -- zellij list-sessions \
    | sed -r 's/\x1B\[[0-9;]*[mK]//g' \
    | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z][^ ]*/) {print $i; break}}')"
  NO_SESSIONS="$(echo "''${ZJ_SESSIONS}" | wc -l)"

  if [ "''${NO_SESSIONS}" -ge 2 ]; then
      read -p "Start new Session? [y/N]: " NEW_SESSION
      if [[ "$NEW_SESSION" =~ ^[JjYy]$ ]]; then
          vm-run -c "$1" "$2" -- zellij --layout /home/user/.config/zellij/layouts/tabs.kdl attach -c
      else
          vm-run -c "$1" "$2" -- zellij attach "$(echo "''${ZJ_SESSIONS}" | fzf)"
      fi
  else
      vm-run -c "$1" "$2" -- zellij --layout /home/user/.config/zellij/layouts/tabs.kdl attach -c
  fi
''
