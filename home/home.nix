{
  pkgs,
  lib,
  ...
}:
let
  kittyConf = import ./kitty.nix;
in
{
  imports = [
    ./zsh.nix
    ./vim.nix
    # ./yazi.nix
    ./hyde.nix
    ./ssh.nix
    ./desktop-entries.nix
    ./vm-connect.nix
  ];

  home = {
    username = "nx";
    homeDirectory = "/home/nx";
    sessionVariables.LANG = "en_US.UTF-8";
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    (writeShellScriptBin "nvim" ''
      #!${pkgs.bash}/bin/bash
      # This script acts as a wrapper to redirect `nvim` calls to the nvim MicroVM.
      # It passes all arguments it receives to the nvim_vm script.
      exec zsh -c 'source /home/nx/nixos-config/home/nvim.zsh; nvim_vm "$@"' _ "$@"
    '')
    # yaziPkg
    zoxide
    # ddate
    oh-my-posh
    neofetch
    fastfetch

    # archives
    # zip
    # xz
    # unzip
    # p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # misc
    # cowsay
    file
    tree

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    # strace # system call monitoring
    # ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb

    nerd-fonts.droid-sans-mono

    # zoom-us
    # discord
    # slack
    # lazygit
    # onlyoffice-desktopeditors
    # gimp
    # inkscape
    # vlc
    # telegram-desktop
    chromium
    # pinta
    # pdfarranger

    # postman
    # jetbrains.phpstorm
    # devenv

    wl-screenrec

    # wine
    # pass
    (import ./coding-zellij.nix { inherit pkgs; })
  ];

  # programs.kitty.enable = true;
  home.file.".config/kitty/kitty.conf" = {
    text = kittyConf;
    force = true;
  };
  home.file.".config/kitty/current-theme.conf".source = ./current-theme.conf;
  home.file.".config/kitty/startup".source = ./startup;

  xdg.mimeApps.enable = lib.mkForce false;

  # zellij
  home.file.".config/zellij".source = ./zellij;

  # Email client
  # programs.himalaya = {
  #   enable = true;
  # };

  home.stateVersion = "25.05";
}
