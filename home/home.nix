{
  pkgs,
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
  ];

  home.username = "nx";
  home.homeDirectory = "/home/nx";

  home.sessionVariables.LANG = "en_US.UTF-8";

  # enable gnome-shell (to make paperwm work)
  programs.gnome-shell.enable = true;

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # set cursor size and dpi for 4k monitor
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  # nixpkgs.config.allowUnfree = true;

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # yaziPkg
    zoxide
    ddate
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
    # strace # system call monitoring
    # ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb

    # Gnome stuff
    gnomeExtensions.paperwm
    gnomeExtensions.user-themes
    dracula-theme
    # tela-icon-theme
    nerd-fonts.droid-sans-mono

    zoom-us
    # discord
    slack
    lazygit
    onlyoffice-bin
    gimp
    vlc
    telegram-desktop
    google-chrome
    pinta
    pdfarranger

    postman
    # jetbrains.phpstorm
    devenv

    tiny
    wezterm
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

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
    extensions = with pkgs; [ gh-copilot ];
  };

  # Icons and theme
  # gtk = {
  #   enable = true;
  #
  #   theme = {
  #     name = "Dracula";
  #     package = pkgs.dracula-theme;
  #   };
  #
  #   iconTheme = {
  #     name = "Tela-dracula-dark";
  #     package = pkgs.tela-icon-theme;
  #   };
  # };

  # dconf settings for gnome shell theme
  # dconf.settings = {
  #   "org/gnome/shell" = {
  #     enabled-extensions = [
  #       "user-theme@gnome-shell-extensions.gcampax.github.com"
  #       "paperwm@paperwm.github.com"
  #       # NOTE: Have manually installed it just here for activation
  #       "trayIconsReloaded@selfmade.pl"
  #     ];
  #   };
  #
  #   "org/gnome/shell/extensions/user-theme" = {
  #     name = "Dracula";
  #   };
  # };

  # git
  programs.git = {
    enable = true;
    userName = "Daniel Kipp";
    userEmail = "daniel.kipp@gmail.com";
    signing = {
      key = "937A32679620DC68";
      signByDefault = true;
    };

    extraConfig = {
      color = {
        branch = "auto";
        diff = "auto";
        interactive = "auto";
        status = "auto";
        ui = "auto";
      };

      "color \"branch\"" = {
        current = "green";
        remote = "yellow";
      };

      alias = {
        co = "checkout";
        st = "status -sb";
        br = "branch";
        ci = "commit";
        fo = "fetch origin";
        d = "!git --no-pager diff";
        dt = "difftool";
        stat = "!git --no-pager diff --stat";
        remoteSetHead = "remote set-head origin --auto";
        defaultBranch = "!git symbolic-ref refs/remotes/origin/HEAD | cut -d'/' -f4";
        sweep = "!git branch --merged $(git defaultBranch) | grep -E -v \" $(git defaultBranch)$\" | xargs -r git branch -d && git remote prune origin";
        lg = "log --graph --all --pretty=format:'%Cred%h%Creset - %s %Cgreen(%cr) %C(bold blue)%an%Creset %C(yellow)%d%Creset'";
        serve = "!git daemon --reuseaddr --verbose  --base-path=. --export-all ./.git";
        m = "!git checkout $(git defaultBranch)";
        unstage = "reset HEAD --";
      };

      help.autocorrect = 1;
      push.default = "simple";
      pull.rebase = false;

      "branch \"main\"".mergeoptions = "--no-edit";
      init.defaultBranch = "main";

      gpg.program = "gpg";
    };
  };

  # programs.kitty.enable = true;
  home.file.".config/kitty/kitty.conf".text = kittyConf;
  home.file.".config/kitty/current-theme.conf".source = ./current-theme.conf;
  home.file.".config/kitty/startup".source = ./startup;

  # zellij
  home.file.".config/zellij".source = ./zellij;

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
      nixfmt

      watchman
    ];
  };
  home.sessionVariables = {
    MASON_DIR = "$HOME/.local/share/nvim/mason";
  };

  # direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.stateVersion = "25.05";
}
