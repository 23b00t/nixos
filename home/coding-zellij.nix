let
  pkgs = import <nixpkgs> {};
in
pkgs.writeShellScriptBin "coding-zellij" ''
  #!/usr/bin/env bash
  ZJ_SESSIONS="$(vm-run -c 1 nvim zellij list-sessions)"
  NO_SESSIONS="$(echo "''${ZJ_SESSIONS}" | wc -l)"

  if [ "''${NO_SESSIONS}" -ge 2 ]; then
      vm-run -c 1 nvim zellij attach \
      "$(echo "''${ZJ_SESSIONS}" | sk)"
  else
      vm-run -c 1 nvim zellij attach -c
  fi
''
