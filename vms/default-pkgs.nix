{ pkgs }:
with pkgs;
[
  btop
  vim
  usbutils
  file
  tree
  lsof
  bibata-cursors
  wl-clipboard

  nerd-fonts.fira-code
  p7zip
  jq
  poppler
  resvg
  imagemagick
  (import ./copy-between-vms.nix { inherit pkgs lib; })
]
