{ config, pkgs, lib, lazyvim-config, ... }:
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
    lazygit
    onlyoffice-bin
    gimp
    vlc
    telegram-desktop
    google-chrome
    pinta
    pdfarranger

    postman
    jetbrains.phpstorm

    devenv
  ];

  programs.gh = {
    enable = true;
    settings = { git_protocol = "ssh"; };
    extensions = with pkgs; [ gh-copilot ];
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
  
  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
      # LazyVim
      lua-language-server
      stylua
      # Telescope
      ripgrep
    ];

    plugins = with pkgs.vimPlugins; [
      lazy-nvim
    ];

    extraLuaConfig =
      let
        plugins = with pkgs.vimPlugins; [
          # LazyVim
          LazyVim
          bufferline-nvim
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
          lualine-nvim
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
          nvim-treesitter
          nvim-treesitter-context
          nvim-treesitter-textobjects
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
          vim-illuminate
          vim-startuptime
          which-key-nvim
          { name = "LuaSnip"; path = luasnip; }
          { name = "catppuccin"; path = catppuccin-nvim; }
          { name = "mini.ai"; path = mini-nvim; }
          { name = "mini.bufremove"; path = mini-nvim; }
          { name = "mini.comment"; path = mini-nvim; }
          { name = "mini.indentscope"; path = mini-nvim; }
          { name = "mini.pairs"; path = mini-nvim; }
          { name = "mini.surround"; path = mini-nvim; }
# Database Tools
          vim-dadbod                # Database client
          vim-dadbod-ui             # UI for database client
          vim-dadbod-completion     # Completions for SQL

# File Management
          oil-nvim                  # File manager
          direnv-vim                # Direnv integration

# Git
          diffview-nvim             # Git diff viewer
          git-blame-nvim            # Git blame info

# Code Actions
          nvim-spectre              # Search/replace panel
          vim-exchange              # Text exchange operator

# AI Assistants
          copilot-lua               # GitHub Copilot (Lua version)
          copilot-cmp               # Copilot completions

# Languages and Frameworks
          vim-ruby                  # Ruby support
          vim-rails                 # Ruby on Rails support
          nvim-jdtls                # Java Language Server
          rust-tools-nvim           # Rust tools

# Markdown and Documentation
          markdown-preview-nvim     # Markdown preview

# Editor Enhancements
          better-escape-nvim        # Better escape from insert mode
          nvim-autopairs            # Auto pairs
          nvim-surround             # Surround text objects
          leap-nvim                 # Quick navigation
          telescope-undo-nvim       # Undo history in telescope
          nvim-ufo                  # Folding improvements
          nvim-bqf                  # Better quickfix window
          twilight-nvim             # Dim inactive code

# Debugging
          nvim-dap                  # Debug Adapter Protocol
          nvim-dap-ui               # UI for DAP
          nvim-dap-virtual-text     # Virtual text for debug info

# Terminal
          toggleterm-nvim           # Better terminal integration
        ];
        mkEntryFromDrv = drv:
          if lib.isDerivation drv then
            { name = "${lib.getName drv}"; path = drv; }
          else
            drv;
        lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv plugins);
      in
    ''
      -- Setup LazyVim with Nix plugins
      require("lazy").setup({
        defaults = {
          lazy = true,
        },
        dev = {
          -- reuse files from pkgs.vimPlugins.*
          path = "${lazyPath}",
          patterns = { "" },
          -- fallback to download
          fallback = true,
        },
        spec = {
          { "LazyVim/LazyVim", import = "lazyvim.plugins" },
          -- The following configs are needed for fixing lazyvim on nix
          -- force enable telescope-fzf-native.nvim
          { "nvim-telescope/telescope-fzf-native.nvim", enabled = true },
          -- disable mason.nvim, use programs.neovim.extraPackages
          { "williamboman/mason-lspconfig.nvim", enabled = false },
          { "williamboman/mason.nvim", enabled = false },
          -- import/override with your plugins
          { import = "plugins" },
          -- treesitter handled by xdg.configFile."nvim/parser", put this line at the end of spec to clear ensure_installed
          { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
        },
      })

      -- Load your custom configurations
      -- Options
      local opt = vim.opt
      require("config.options")
      
      -- Autocmds
      local function augroup(name)
        return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
      end
      require("config.autocmds")
      
      -- Keymaps
      local keymap = vim.keymap
      local opts = { noremap = true, silent = true }
      require("config.keymaps")
      
      -- Set up any additional global functions or variables
      _G.OS = vim.loop.os_uname().sysname
      
      -- Load user custom commands
      if vim.fn.filereadable(vim.fn.expand("~/.config/nvim/lua/config/commands.lua")) == 1 then
        require("config.commands")
      end
    '';
  };

  # https://github.com/nvim-treesitter/nvim-treesitter#i-get-query-error-invalid-node-type-at-position
  xdg.configFile."nvim/parser".source =
    let
      parsers = pkgs.symlinkJoin {
        name = "treesitter-parsers";
        paths = (pkgs.vimPlugins.nvim-treesitter.withPlugins (plugins: with plugins; [
          c
          lua
          bash
          javascript
          typescript
          ruby
          php
          rust
          python
          html
          css
          json
          yaml
          nix
          markdown
        ])).dependencies;
      };
    in
    "${parsers}/parser";

  # Direct file references - much cleaner!
  xdg.configFile."nvim/lua".source = ./lazyvim/lua;
  xdg.configFile."nvim/spell".source = ./lazyvim/spell;
  
  # Create spell directory if it doesn't exist
  home.activation.createNeovimDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${config.home.homeDirectory}/.local/share/nvim/site/spell
  '';

  home.stateVersion = "25.05";
}
