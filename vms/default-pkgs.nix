{ pkgs }:
let
  socktop-bundle = import ../pkgs/socktop-bundle.nix {
    inherit (pkgs) stdenv rustPlatform fetchFromGitHub pkg-config libdrm;
  };
in
with pkgs;
[
  btop
  vim
  usbutils
  file
  tree
  lsof
  bibata-cursors
  socktop-bundle
]
