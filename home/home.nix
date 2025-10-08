{
  pkgs,
  ...
}:
{
  imports = [
    ./zsh.nix
  ];

  home.username = "yula";
  home.homeDirectory = "/home/yula";

  home.sessionVariables.LANG = "de_DE.UTF-8";

  # enable gnome-shell (to make paperwm work)
  programs.gnome-shell.enable = true;

  # set cursor size and dpi for 4k monitor
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  nixpkgs.config.allowUnfree = true;

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    oh-my-posh
    neofetch

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # misc
    cowsay
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
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb

    gnomeExtensions.user-themes
    dracula-theme
    tela-icon-theme
    nerd-fonts.droid-sans-mono

    zoom-us
    discord
    onlyoffice-bin
    gimp
    vlc
    telegram-desktop
    google-chrome
    pinta
    pdfarranger
    geany

    tor-browser

    superTuxKart
    superTux

    inkscape-with-extensions
  ];

  programs = {
    firefox = {
      enable = true;
      languagePacks = [
        "de"
        "en-US"
      ];
    };
  };

  # Icons and theme
  gtk = {
    enable = true;

    theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };

    iconTheme = {
      name = "Tela-dracula-dark";
      package = pkgs.tela-icon-theme;
    };
  };

  # dconf settings for gnome shell theme
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "user-theme@gnome-shell-extensions.gcampax.github.com"
      ];
    };

    "org/gnome/shell/extensions/user-theme" = {
      name = "Dracula";
    };
  };

  home.stateVersion = "25.05";
}
