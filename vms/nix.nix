{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nil
    # nixd
    nixdoc
    nixfmt
    deadnix
  ];
}
