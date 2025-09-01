{
  description = "Nixos config by 23b00t";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lazyvim-config = {
      url = "github:23b00t/lazyvim";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, lazyvim-config, ... }@inputs: {
    nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      specialArgs = { inherit lazyvim-config; };
      
      modules = [
        ./machines/h/configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = false;
          home-manager.users.nx = {
            nixpkgs.config.allowUnfree = true;
            imports = [ ./home/home.nix ];
          };
          home-manager.extraSpecialArgs = {
            inherit lazyvim-config;
          };
        }
      ];
    };

    # --- DevShells ---
    devShells."x86_64-linux" = let
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
        };
      };

      # --- Setup-Skript für LazyVim-Konfiguration ---
      setup-lazyvim = pkgs.writeShellScriptBin "setup-lazyvim" ''
        # Konfigurationspfade
        CONFIG_DIR="$HOME/.config/nvim-dev"
        DATA_DIR="$HOME/.local/share/nvim-dev"
        STATE_DIR="$HOME/.local/state/nvim-dev"
        CACHE_DIR="$HOME/.cache/nvim-dev"
        
        # Verzeichnisse erstellen
        mkdir -p "$CONFIG_DIR/spell" "$DATA_DIR/site/spell" "$STATE_DIR" "$CACHE_DIR"
        
        # Nur kopieren, wenn noch nicht vorhanden
        if [ ! -f "$CONFIG_DIR/.config_copied" ]; then
          echo "Kopiere LazyVim-Konfiguration..."
          
          # Lösche vorhandene Konfiguration, um sauberen Start zu gewährleisten
          rm -rf "$CONFIG_DIR/lua" "$CONFIG_DIR/init.lua" 2>/dev/null || true
          
          # Kopiere die gesamte Konfiguration
          cp -r "${lazyvim-config}/"* "$CONFIG_DIR/" 2>/dev/null || true
          
          # Mache alle Dateien beschreibbar
          find "$CONFIG_DIR" -type f -exec chmod u+w {} \; 2>/dev/null || true
          
          # Marker setzen
          touch "$CONFIG_DIR/.config_copied"
        fi
        
        # Treesitter-Parser-Verzeichnis verlinken
        PARSER_DIR="${treesitterPath}"
        if [ -d "$PARSER_DIR" ]; then
          mkdir -p "$CONFIG_DIR/parser"
          ln -sf "$PARSER_DIR"/* "$CONFIG_DIR/parser/" 2>/dev/null || true
        fi
        
        # Spell-Dateien kopieren
        SPELL_SOURCE="$HOME/.config/nvim/spell"
        if [ -d "$SPELL_SOURCE" ]; then
          for spell_file in "$SPELL_SOURCE"/*.{spl,sug}; do
            if [ -f "$spell_file" ]; then
              cp -f "$spell_file" "$CONFIG_DIR/spell/$(basename "$spell_file")" 2>/dev/null || true
            fi
          done
        fi
        
        # Lazy.nvim-Setup in init.lua einfügen
        # Wir erstellen eine neue init.lua oder passen die vorhandene an
        if [ -f "$CONFIG_DIR/init.lua" ]; then
          # Sichern der Original-Datei
          cp "$CONFIG_DIR/init.lua" "$CONFIG_DIR/init.lua.original"
          
          # Temporäre Datei erstellen
          TMP_INIT=$(mktemp)
          
          # Unsere Konfiguration oben einfügen
          cat > "$TMP_INIT" << 'EOF'
-- XDG-Variablen für separate Konfiguration
vim.env.XDG_DATA_HOME = vim.env.HOME .. "/.local/share/nvim-dev"
vim.env.XDG_STATE_HOME = vim.env.HOME .. "/.local/state/nvim-dev"
vim.env.XDG_CACHE_HOME = vim.env.HOME .. "/.cache/nvim-dev"

-- Stelle sicher, dass diese Konfiguration im Runtimepfad ist
vim.opt.runtimepath:append(vim.env.HOME .. "/.config/nvim-dev")

-- Lazy.nvim-Konfiguration für Nix
local lazypath = vim.env.XDG_DATA_HOME .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- Lazy-Plugin-Setup mit Nix-Integration
require("lazy").setup({
  defaults = { lazy = true },
  dev = {
    -- Plugins aus Nix-Store verwenden
    path = "${lazyPath}",
    patterns = { "" },
    fallback = true,
  },
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Nix-spezifische Konfiguration
    { "nvim-telescope/telescope-fzf-native.nvim", enabled = true },
    -- Mason deaktivieren, alles über Nix
    { "williamboman/mason-lspconfig.nvim", enabled = false },
    { "williamboman/mason.nvim", enabled = false },
    -- Eigene Plugins laden
    { import = "plugins" },
    -- Treesitter über Nix
    { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
  },
})

EOF
          
          # Original-Inhalt (ohne Lazy-Setup) anfügen, falls vorhanden
          if grep -q "require(\"config.lazy\")" "$CONFIG_DIR/init.lua.original"; then
            # Wir haben ein Standard-LazyVim-Setup, können unseres verwenden
            echo "Standard-LazyVim-Setup gefunden, wird durch Nix-Version ersetzt."
          else
            # Andere Initialisierung, an unsere anfügen
            cat "$CONFIG_DIR/init.lua.original" >> "$TMP_INIT"
          fi
          
          # Ersetze die Original-Datei
          mv "$TMP_INIT" "$CONFIG_DIR/init.lua"
          chmod u+w "$CONFIG_DIR/init.lua"
        else
          # Erstelle eine neue init.lua
          cat > "$CONFIG_DIR/init.lua" << 'EOF'
-- XDG-Variablen für separate Konfiguration
vim.env.XDG_DATA_HOME = vim.env.HOME .. "/.local/share/nvim-dev"
vim.env.XDG_STATE_HOME = vim.env.HOME .. "/.local/state/nvim-dev"
vim.env.XDG_CACHE_HOME = vim.env.HOME .. "/.cache/nvim-dev"

-- Stelle sicher, dass diese Konfiguration im Runtimepfad ist
vim.opt.runtimepath:append(vim.env.HOME .. "/.config/nvim-dev")

-- Lazy.nvim-Konfiguration für Nix
local lazypath = vim.env.XDG_DATA_HOME .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- Lazy-Plugin-Setup mit Nix-Integration
require("lazy").setup({
  defaults = { lazy = true },
  dev = {
    -- Plugins aus Nix-Store verwenden
    path = "${lazyPath}",
    patterns = { "" },
    fallback = true,
  },
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Nix-spezifische Konfiguration
    { "nvim-telescope/telescope-fzf-native.nvim", enabled = true },
    -- Mason deaktivieren, alles über Nix
    { "williamboman/mason-lspconfig.nvim", enabled = false },
    { "williamboman/mason.nvim", enabled = false },
    -- Eigene Plugins laden
    { import = "plugins" },
    -- Treesitter über Nix
    { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
  },
})

-- Lade deine Konfiguration
require("config.lazy")
EOF
        fi
        
        echo "LazyVim-Konfiguration erfolgreich eingerichtet in $CONFIG_DIR"
      '';

      # --- Wrapper-Skript für Neovim mit LazyVim-Konfiguration ---
      nvim-lazyvim = pkgs.writeShellScriptBin "nvim" ''
        # Führe das Setup-Skript aus
        setup-lazyvim
        
        # Starte Neovim mit der richtigen Konfiguration
        NVIM_APPNAME="nvim-dev" XDG_CONFIG_HOME="$HOME/.config" ${pkgs.neovim}/bin/nvim "$@"
      '';

      # --- Treesitter-Parser ---
      treesitterPath =
        let
          parsers = pkgs.symlinkJoin {
            name = "treesitter-parsers";
            paths = (pkgs.vimPlugins.nvim-treesitter.withPlugins (plugins: with plugins; [
              # Basis-Parser
              c lua bash comment regex 
              
              # Web-Entwicklung
              html css javascript typescript tsx json yaml
              
              # Backend
              php python ruby go rust
              
              # Konfiguration
              toml nix markdown
            ])).dependencies;
          };
        in
        "${parsers}/parser";

      # --- Liste aller Plugins für LazyVim ---
      plugins = with pkgs.vimPlugins; [
        # LazyVim Kern-Plugins
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
        
        # Zusätzliche Plugins basierend auf deiner Konfiguration
        vim-visual-multi
        typescript-vim
        vim-jsx-typescript
        vim-surround
        rainbow-delimiters-nvim
        vim-exchange
        autosave-nvim
        windsurf-vim
        github-nvim-theme
        copilot-lua
        copilot-cmp
        nvim-dap
        nvim-dap-ui
        edgy-nvim
        vim-rails
        orgmode
        vim-ReplaceWithRegister
        toggleterm-nvim
        tiny-inline-diagnostic-nvim
      ];
      
      # --- Plugin-Pfad für lazy.nvim ---
      lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map 
        (drv: if lib.isDerivation drv then { name = "${lib.getName drv}"; path = drv; } else drv) 
        plugins);

    in {
      # Haupt-DevShell für Editor + Sprachen + Tools
      dev = pkgs.mkShell {
        packages = with pkgs; [
          # --- LazyVim statt Standard-Neovim ---
          nvim-lazyvim
          setup-lazyvim
          
          # Tools für Neovim
          ripgrep            # Für Telescope
          fd                 # Schnellere Alternative zu find
          stylua             # Lua-Formatter
          
          # Basis-Tools
          zsh lazygit
          tree-sitter
          cmake pkg-config gnumake
          gcc clang
          
          # Sprachen und LSPs basierend auf deiner Konfiguration
          
          # Lua
          lua-language-server
          
          # JS / TS / Web
          nodejs
          nodePackages.typescript
          nodePackages.typescript-language-server
          nodePackages.vscode-langservers-extracted # html, css, json
          nodePackages.yaml-language-server
          nodePackages.dockerfile-language-server-nodejs
          nodePackages.eslint_d
          nodePackages.prettier
          yarn
          
          # Python
          python3
          pyright
          python3Packages.black
          python3Packages.isort
          python3Packages.ruff
          
          # PHP
          php81
          php82
          php83
          php81Packages.composer
          php82Packages.composer
          php83Packages.composer
          symfony-cli
          nodePackages.intelephense  # PHP LSP
          php83Extensions.xdebug
          php82Extensions.xdebug
          php81Extensions.xdebug
          
          # Webserver & Debugging
          nodePackages.live-server
          xdg-utils
          
          # Nix
          nil
          nixpkgs-fmt
          
          # Ruby
          asdf-vm 
          openssl
          zlib
          bzip2
          libffi
          readline
          libyaml
          gdbm
          ncurses
          xz
          
          # Bash / Shell
          nodePackages.bash-language-server
          shellcheck
          shfmt
          
          # Rust
          rustup
          rust-analyzer
          
          # DB-Clients
          postgresql
          mariadb
          
          # Sonstiges nützliches
          jq
        ];

        shellHook = ''
          echo
          echo "LazyVim DevShell aktiv."

          # Oh-My-Posh Theme
          export OMP_CONFIG="''${OMP_CONFIG:-$HOME/.cache/oh-my-posh/themes/amro.omp.json}"

          # asdf
          export ASDF_DIR="${pkgs.asdf-vm}/share/asdf-vm"
          export ASDF_DATA_DIR="$HOME/.asdf"
          if [ -f "$ASDF_DIR/asdf.sh" ]; then
            . "$ASDF_DIR/asdf.sh"
          fi
          # Shims sicher in den PATH (falls asdf.sh das nicht schon getan hat)
          export PATH="$ASDF_DATA_DIR/shims:$PATH"

          # PHP-Versionen mit Symlinks verwalten (NixOS-kompatibel)
          mkdir -p $HOME/bin
          export PATH="$HOME/bin:$PATH"
          
          # PHP-Binaries
          ln -sf ${pkgs.php81}/bin/php $HOME/bin/php-8.1
          ln -sf ${pkgs.php82}/bin/php $HOME/bin/php-8.2
          ln -sf ${pkgs.php83}/bin/php $HOME/bin/php-8.3
          
          # Composer für jede Version
          ln -sf ${pkgs.php81Packages.composer}/bin/composer $HOME/bin/composer-8.1
          ln -sf ${pkgs.php82Packages.composer}/bin/composer $HOME/bin/composer-8.2
          ln -sf ${pkgs.php83Packages.composer}/bin/composer $HOME/bin/composer-8.3
          
          # Standard ist PHP 8.3
          if [ ! -e "$HOME/bin/php" ] || [ ! -e "$HOME/bin/composer" ]; then
            ln -sf $HOME/bin/php-8.3 $HOME/bin/php
            ln -sf $HOME/bin/composer-8.3 $HOME/bin/composer
          fi
          
          # Einfaches Wechsel-Skript erstellen
          cat > $HOME/bin/php-switch <<EOF
          #!/usr/bin/env bash
          if [ "\$1" == "8.1" ] || [ "\$1" == "81" ]; then
            rm -f \$HOME/bin/php \$HOME/bin/composer
            ln -sf \$HOME/bin/php-8.1 \$HOME/bin/php
            ln -sf \$HOME/bin/composer-8.1 \$HOME/bin/composer
            echo "PHP 8.1 aktiviert: \$(php -v | head -n 1)"
          elif [ "\$1" == "8.2" ] || [ "\$1" == "82" ]; then
            rm -f \$HOME/bin/php \$HOME/bin/composer
            ln -sf \$HOME/bin/php-8.2 \$HOME/bin/php
            ln -sf \$HOME/bin/composer-8.2 \$HOME/bin/composer
            echo "PHP 8.2 aktiviert: \$(php -v | head -n 1)"
          elif [ "\$1" == "8.3" ] || [ "\$1" == "83" ]; then
            rm -f \$HOME/bin/php \$HOME/bin/composer
            ln -sf \$HOME/bin/php-8.3 \$HOME/bin/php
            ln -sf \$HOME/bin/composer-8.3 \$HOME/bin/composer
            echo "PHP 8.3 aktiviert: \$(php -v | head -n 1)"
          else
            echo "Verwendung: php-switch <version>"
            echo "Verfügbare Versionen: 8.1, 8.2, 8.3"
            echo "Aktuelle PHP-Version: \$(php -v | head -n 1)"
          fi
          EOF
          chmod +x $HOME/bin/php-switch

          # Node corepack etc.
          if command -v corepack >/dev/null 2>&1; then
            corepack enable >/dev/null 2>&1 || true
          fi

          # Rustup: Falls keine Toolchain gesetzt
          if command -v rustup >/dev/null 2>&1 && ! command -v rustc >/dev/null 2>&1; then
            rustup toolchain install stable >/dev/null 2>&1 || true
            rustup default stable >/dev/null 2>&1 || true
            rustup component add rust-analyzer >/dev/null 2>&1 || true
          fi

          echo
          echo "LazyVim Setup: Verwendet deine persönliche Konfiguration aus 23b00t/lazyvim"
          echo "Mason ist deaktiviert - alle Tools werden direkt über Nix bereitgestellt"
          echo
          echo "Ruby:"
          echo "  asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git"
          echo "  asdf install ruby 3.3.4"
          echo "  asdf global ruby 3.3.4"
          echo
          echo "PHP: PHP 8.1-8.3 mit php-switch"
          echo "  Wechseln zwischen Versionen: php-switch 8.1|8.2|8.3"
          echo "  Aktuelle Version: $(php -v | head -n 1)"
          echo "  LSP: intelephense ist im PATH"
          echo
          echo "Webserver & Debugging:"
          echo "  live-server: HTML/JS Live-Server"
          echo "  php -S localhost:8000: PHP Builtin-Server"
          echo
          echo "JS/TS/HTML/CSS: typescript-language-server, vscode-langservers-extracted, eslint_d, prettier"
          echo "Python: pyright, black, isort, ruff"
          echo "Shell: bash-language-server, shellcheck, shfmt"
          echo "Rust: rustup + rust-analyzer"
          echo "DB-Clients: psql (PostgreSQL), mariadb"
          echo
        '';
      };

      # Separate Shell für Container-Tools
      containers = pkgs.mkShell {
        packages = with pkgs; [
          lazydocker
          dive
          ctop
          docker-slim
          podman-tui
          distrobox
        ];
        shellHook = ''
          echo
          echo "Container-Tools-Shell aktiv:"
          echo "  lazydocker, dive, ctop, podman-tui im PATH."
          echo
        '';
      };

      # Alias
      default = self.devShells."x86_64-linux".dev;
    };
  };
}
