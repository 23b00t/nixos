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

      # --- NEU: Ein einfaches, aber effektives LazyVim-Setup ---
      # Erstellt eine Shell-Umgebung, die beim Start von Neovim die LazyVim-Konfiguration verwendet
      # --- VERBESSERT: Ein funktionierendes LazyVim-Setup mit Spell-Support ---
      devNeovim = pkgs.writeShellScriptBin "nvim" ''
        # Erstelle XDG_CONFIG_HOME, falls es nicht existiert
        TEMP_CONFIG_DIR="$HOME/.config/nvim-dev"
        mkdir -p "$TEMP_CONFIG_DIR"

        # Erstelle die erforderlichen Datenverzeichnisse
        TEMP_DATA_DIR="$HOME/.local/share/nvim-dev"
        TEMP_STATE_DIR="$HOME/.local/state/nvim-dev"
        TEMP_CACHE_DIR="$HOME/.cache/nvim-dev"
        mkdir -p "$TEMP_DATA_DIR"
        mkdir -p "$TEMP_STATE_DIR"
        mkdir -p "$TEMP_CACHE_DIR"

        # Erstelle ein Spell-Verzeichnis, das beschreibbar ist
        mkdir -p "$TEMP_DATA_DIR/site/spell"
        
        # Verlinke die Spell-Dateien aus deiner regulären Neovim-Konfiguration
        # Wenn du deine Konfiguration über home-manager verwaltest, befinden sich die Spell-Dateien im Nix-Store
        SPELL_SOURCE="$HOME/.config/nvim/spell"
        if [ -d "$SPELL_SOURCE" ]; then
          for spell_file in "$SPELL_SOURCE"/*.{spl,sug}; do
            if [ -f "$spell_file" ]; then
              ln -sf "$spell_file" "$TEMP_CONFIG_DIR/spell/$(basename "$spell_file")" 2>/dev/null || true
            fi
          done
        fi

        # Stelle die Verbindung zur LazyVim-Konfiguration her (via Symlink)
        ln -sfn "${lazyvim-config}/lua" "$TEMP_CONFIG_DIR/lua"

        # Erstelle eine minimale init.lua, die deine Konfiguration lädt
        cat > "$TEMP_CONFIG_DIR/init.lua" << 'EOF'
        -- Diese init.lua lädt deine LazyVim-Konfiguration
        -- Setze XDG-Variablen, damit Plugins in der devShell installiert werden
        vim.env.XDG_DATA_HOME = vim.env.HOME .. "/.local/share/nvim-dev"
        vim.env.XDG_STATE_HOME = vim.env.HOME .. "/.local/state/nvim-dev"
        vim.env.XDG_CACHE_HOME = vim.env.HOME .. "/.cache/nvim-dev"

        -- Stellen sicher, dass Spell-Dateien gefunden werden
        vim.opt.runtimepath:append(vim.env.HOME .. "/.config/nvim-dev")
        
        -- Standard LazyVim-Bootstrap-Code
        local lazypath = vim.env.XDG_DATA_HOME .. "/lazy/lazy.nvim"
        if not vim.loop.fs_stat(lazypath) then
          vim.fn.system({
            "git",
            "clone",
            "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git",
            "--branch=stable",
            lazypath,
          })
        end
        vim.opt.rtp:prepend(lazypath)

        -- Lade die Konfiguration aus dem Modul "config.lazy"
        require("config.lazy")
        EOF

        # Erstelle das Spell-Verzeichnis in der Neovim-Konfiguration
        mkdir -p "$TEMP_CONFIG_DIR/spell"
        
        # Kopiere die deutschen Spell-Dateien direkt aus dem Nix-Store in die Konfiguration
        if [ -d "${lazyvim-config}/spell" ]; then
          cp -f "${lazyvim-config}/spell/"*.{spl,sug} "$TEMP_CONFIG_DIR/spell/" 2>/dev/null || true
        fi

        # Starte Neovim mit der temporären Konfiguration
        XDG_CONFIG_HOME="$HOME/.config" NVIM_APPNAME="nvim-dev" ${pkgs.neovim}/bin/nvim "$@"
      '';

    in {
      # Haupt-DevShell für Editor + Sprachen + Tools
      dev = pkgs.mkShell {
        packages = with pkgs; [
          # --- GEÄNDERT: Ersetze Neovim durch unser Skript ---
          devNeovim 
          
          # Alle anderen Pakete bleiben unverändert
          zsh lazygit
          fd tree-sitter
          cmake pkg-config gnumake
          gcc clang

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

          # PHP mit mehreren Versionen
          php81
          php82
          php83
          php81Packages.composer
          php82Packages.composer
          php83Packages.composer
          symfony-cli
          nodePackages.intelephense  # PHP LSP

          # Webserver & Debugging Tools für Neovim
          php83Extensions.xdebug
          php82Extensions.xdebug
          php81Extensions.xdebug
          nodePackages.live-server         # JS/HTML Live-Server
          xdg-utils                        # Für xdg-open (Browser-Öffnen)

          # Nix LSP und Tools für Neovim
          nil                              # Nix Language Server
          nixpkgs-fmt                      # Nix Formatter

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

          # Rust (Versionsverwaltung via rustup)
          rustup
          rust-analyzer

          # DB-Clients
          postgresql
          mariadb

          # Sonstiges nützliches
          lua-language-server
          jq
          ripgrep # Für Telescope erforderlich
          stylua  # Für LazyVim
        ];

        shellHook = ''
          echo
          echo "DevShell aktiv."

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
          echo "  php-debug-adapter: Für PHP Debugging in Neovim verfügbar"
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
