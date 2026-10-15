{
  pkgs,
  lib ? pkgs.lib,
  vmRegistry,
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
  # 7-Zip (7zz, used by yazi to extract): zip, 7z, tar.*, and RAR where
  # unfree packages are allowed (RAR extraction is unfree)
  (if pkgs.config.allowUnfree or false then _7zz-rar else _7zz)
  jq
  poppler
  resvg
  imagemagick
  (import ./copy-between-vms.nix { inherit pkgs lib vmRegistry; })

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
