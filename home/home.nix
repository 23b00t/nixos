{
  pkgs,
  ...
}:
let
  kittyConf = import ./kitty.nix;
in
{
  imports = [
    ./zsh.nix
    ./vim.nix
    ./yazi.nix
    ./hyde.nix
    ./shared.nix
  ];

  home.username = "nx";
  home.homeDirectory = "/home/nx";

  home.sessionVariables.LANG = "en_US.UTF-8";

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # yaziPkg
    ddate

    # misc
    cowsay
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

    zoom-us
    # discord
    slack
    onlyoffice-bin
    gimp
    vlc
    telegram-desktop
    google-chrome
    pinta
    pdfarranger

    postman
    # jetbrains.phpstorm

    tiny
    wl-screenrec
    wine
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

  # programs.kitty.enable = true;
  home.file.".config/kitty/kitty.conf" = {
    text = kittyConf;
    force = true;
  };
  home.file.".config/kitty/current-theme.conf".source = ./current-theme.conf;
  home.file.".config/kitty/startup".source = ./startup;

  xdg.configFile."mimeapps.list".force = true;

  # zellij
  home.file.".config/zellij".source = ./zellij;

  home.stateVersion = "25.05";
}
