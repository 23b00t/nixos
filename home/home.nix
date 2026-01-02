{
  pkgs,
  lib,
  inputs,
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
    ./ssh.nix
    ./desktop-entries.nix
    ./vm-connect.nix
    inputs.flatpaks.homeModules.default
  ];

  home = {
    username = "nx";
    homeDirectory = "/home/nx";
    sessionVariables.LANG = "en_US.UTF-8";
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # (writeShellScriptBin "nvim" ''
    #   #!${pkgs.bash}/bin/bash
    #   # This script acts as a wrapper to redirect `nvim` calls to the nvim MicroVM.
    #   # It passes all arguments it receives to the nvim_vm script.
    #   exec zsh -c 'source /home/nx/nixos-config/home/nvim.zsh; nvim_vm "$@"' _ "$@"
    # '')
    # yaziPkg
    flatpak
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
    lazygit
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
    vectorcode

    wl-screenrec
    github-copilot-cli

    # wine
    # pass
    (import ./remote-zellij.nix { inherit pkgs; })
    (import ./backup.nix { inherit pkgs; })
  ];

  # programs.direnv = {
  #   enable = true;
  #   nix-direnv.enable = true;
  # };

  # programs.kitty.enable = true;
  home.file.".config/kitty/kitty.conf" = {
    text = kittyConf;
    force = true;
  };
  home.file.".config/kitty/current-theme.conf".source = ./current-theme.conf;
  home.file.".config/kitty/startup".source = ./startup;

  # TODO: Debug whats going on when enabled
  xdg.mimeApps.enable = lib.mkForce false;

  # zellij
  home.file.".config/zellij".source = ./zellij;

  # oh-my-posh theme
  home.file.".cache/oh-my-posh/themes/slimfat.omp.json".source = ./resources/slimfat.omp.json;

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };

  # git
  programs.git = {
    enable = true;
    signing = {
      key = "937A32679620DC68";
      signByDefault = true;
    };

    settings = {
      user.name = "Daniel Kipp";
      user.email = "daniel.kipp@gmail.com";

      help.autocorrect = 1;
      push.default = "simple";
      pull.rebase = false;

      init.defaultBranch = "main";

      gpg.program = "gpg";
    };
  };
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withNodeJs = true;
    withPython3 = true;
    extraPackages = with pkgs; [
      python3
      fd
      unzip

      gcc
      gnumake

      nodejs
      rustc
      cargo
      rust-analyzer
      watchexec

      lua-language-server
      lua51Packages.lua
      lua51Packages.luarocks
      nixfmt
      statix

      watchman
    ];
  };
  home.sessionVariables = {
    MASON_DIR = "$HOME/.local/share/nvim/mason";
  };

  services.flatpak = {
    enable = true;
    flatpakDir = "/home/nx/.local/share/flatpak";
    remotes = {
      "flathub" = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      "flathub-beta" = "https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo";
    };
    packages = [
      "flathub:app/org.godotengine.Godot/x86_64/stable"
    ];
  };

  home.stateVersion = "25.05";
}
