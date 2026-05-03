{ pkgs, ... }:
pkgs.writeShellScriptBin "explorer" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # define an array of vms importing yazi
  # TODO: automatically generate this list from registration.nix
  vms=(
    "nvim"
    "chat"
    "net"
    "kali"
    "office"
    "vault"
    "php"
    "ruby"
    "sys-usb"
    "nix"
    "coding"
  )

  # Populate rofi with it
  selected=$(printf '%s\n' "''${vms[@]}" | rofi -dmenu -i -p "Start VM" -theme ~/.config/rofi/config.rasi)

  # If a selection was made, start the corresponding VM and open yazi in it
  kitty -e vm-run -c "$selected" yazi
''
