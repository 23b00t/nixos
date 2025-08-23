{ config, pkgs, lib, ... }:
let
  kittyConf = import ./kitty.nix;
in
{
  imports = [
    ./zsh.nix
    ./vim.nix
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
  
  nixpkgs.config.allowUnfree = true;

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    oh-my-posh
    neofetch
    nnn # terminal file manager

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

    btop  # replacement of htop/nmon
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

    # Gnome stuff
    gnomeExtensions.paperwm
    gnomeExtensions.user-themes
    dracula-theme
    tela-icon-theme
    nerd-fonts.droid-sans-mono

    firefox
    zoom-us
    discord
    neovim
    lazygit
    onlyoffice-bin
    gimp
    vlc
  ];


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
          "paperwm@paperwm.github.com"
      ];
    };

    "org/gnome/shell/extensions/user-theme" = {
      name = "Dracula";
    };
  };

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
  
  # nvim with LazyVim config, managed declaratively by Nix
  # Based on the method from https://github.com/LazyVim/LazyVim/discussions/1972
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    # 1. Definiere alle Plugins, die LazyVim standardmäßig benötigt.
    #    Diese werden von nixpkgs bereitgestellt.
    plugins = with pkgs.vimPlugins; [
      # Kern-Plugin-Manager
      lazy-nvim

      # Kern-Plugins für LazyVim
      LazyVim
      (catppuccin-nvim.override { variant = "macchiato"; }) # Beispiel: Variante hier festlegen
      cmp-buffer
      cmp-nvim-lsp
      cmp-path
      cmp_luasnip
      conform-nvim
      dashboard-nvim
      dressing-nvim
      flash-nvim
      friendly-snippets
      gitsigns-nvim
      indent-blankline-nvim
      lazydev-nvim
      lualine-nvim
      luasnip
      mason-nvim
      mason-lspconfig-nvim
      mini-nvim # Stellt mini.ai, mini.indentscope, etc. bereit
      neo-tree-nvim
      neoconf-nvim
      neodev-nvim
      noice-nvim
      nui-nvim
      nvim-cmp
      nvim-lint
      nvim-lspconfig
      nvim-notify
      nvim-spectre
      nvim-treesitter.withAllGrammars # Alle Treesitter-Parser für die Syntaxhervorhebung
      nvim-ts-autotag
      nvim-ts-context-commentstring
      nvim-web-devicons
      persistence-nvim
      plenary-nvim
      telescope-fzf-native-nvim
      telescope-nvim
      todo-comments-nvim
      tokyonight-nvim
      trouble-nvim
      which-key-nvim

      # Deine zusätzlichen Plugins hier einfügen, z.B.:
      # copilot-lua
      # copilot-cmp
    ];

    # 2. Definiere externe Abhängigkeiten, die von den Plugins benötigt werden.
    extraPackages = with pkgs; [
      # Für Telescope
      ripgrep
      # Für nvim-lint
      stylua
      # Für Mason/LSP (Beispiele)
      lua-language-server
      nil # Nix Language Server
      phpactor
    ];

    # 3. Konfiguriere LazyVim, um die von Nix verwalteten Plugins zu verwenden
    #    und deine benutzerdefinierte Konfiguration zu laden.
    extraLuaConfig = ''
      -- Deaktiviere netrw
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1

      require("lazy").setup({
        -- Lass LazyVim wissen, dass es keine Plugins herunterladen soll,
        -- da sie bereits von Nix bereitgestellt werden.
        checker = { enabled = false },
        
        -- Wichtig: Hier gibst du den Pfad zu deinen eigenen Konfigurationsdateien an.
        -- Wir importieren die Standard-LazyVim-Plugins und dann deine eigenen Anpassungen.
        spec = {
          { "LazyVim/LazyVim", import = "lazyvim.plugins" },
          { import = "plugins" },
        },
      })
    '';
  };

  # 4. Verlinke deine persönliche Lua-Konfiguration (init.lua, lua/plugins/*, etc.)
  #    Dies ist der einzige Teil, den wir aus deinem Verzeichnis verlinken.
  #    Stelle sicher, dass dieser Pfad relativ zur home.nix korrekt ist.
  home.file.".config/nvim" = {
    source = ./lazyvim; # Dein Verzeichnis mit init.lua, lua/
    recursive = true;
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}
