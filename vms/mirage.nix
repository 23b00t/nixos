{ pkgs, ... }:
{
  # No zellij here (yazi comes with the dev role)
  services.zellij-env.enable = false;

  environment.systemPackages = with pkgs; [
    opam
    mercurial
    darcs
    bubblewrap
    gcc
    gnumake
    pkg-config
    rsync
    pkg-config
  ];
}
