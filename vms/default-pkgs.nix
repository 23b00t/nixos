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

  (pkgs.runCommand "socktop_agent-only" { buildInputs = [ pkgs.socktop ]; } ''
    mkdir -p $out/bin
    ln -s ${pkgs.socktop}/bin/socktop_agent $out/bin/socktop_agent
  '')
]
