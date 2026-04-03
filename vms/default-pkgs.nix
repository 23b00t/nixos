{
  pkgs,
  lib ? pkgs.lib,
}:
with pkgs;
[
  btop
  vim
  usbutils
  file
  tree
  lsof
  bibata-cursors

  nerd-fonts.fira-code
  p7zip
  jq
  poppler
  resvg
  imagemagick
  (import ./copy-between-vms.nix { inherit pkgs lib; })

  # NOTE: Important that WAYLAND_DISPLAY = "wayland-0" is set as a fake var too
  # Create fake wl-copy
  (pkgs.writeShellScriptBin "wl-copy" ''
    #!/usr/bin/env sh
    cat > /tmp/fake-clipboard
  '')
  # Create fake wl-paste
  (pkgs.writeShellScriptBin "wl-paste" ''
    #!/usr/bin/env sh 
    if [ -f /tmp/fake-clipboard ]; then
      cat /tmp/fake-clipboard
    else
      echo ""
    fi 
  '')
]
