{ pkgs, ... }:
{
  home.username = "nx";
  home.homeDirectory = "/home/nx";

  home.sessionVariables.LANG = "en_US.UTF-8";

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    btop  # replacement of htop/nmon
  ];

  home.stateVersion = "25.05";
}
