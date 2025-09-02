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

      # --- Neovim mit erweiterter FHS-Umgebung ---
      neovimFHS = pkgs.buildFHSEnv {
        name = "nvim-fhs";
        
        # Kritische Systembibliotheken für dynamisch verlinkte Programme
        targetPkgs = pkgs: (with pkgs; [
          # Systembibiotheken für dynamisches Linking
          stdenv.cc.cc.lib  # libstdc++
          zlib
          glib
          xorg.libX11
          xorg.libXau
          xorg.libXdmcp
          xorg.libXext
          xorg.libxcb
          ncurses
          
          # .NET/Mono-Abhängigkeiten für marksman
          icu              # Internationalisierung (libicu)
          dotnet-runtime   # .NET-Laufzeitumgebung
          dotnet-sdk       # .NET SDK
          mono             # Mono für ältere .NET-Anwendungen
          
          # Neovim und Grundvoraussetzungen
          neovim
          git
          curl
          unzip
          gnumake
          gcc
          xz
          
          # Language Server und Tools
          nodejs
          python3
          rustup
          gcc
          lua-language-server
          nil
          ripgrep
          fd
          
          # Sprachen und Linter/Formatter
          nodePackages.typescript
          nodePackages.typescript-language-server
          nodePackages.vscode-langservers-extracted
          nodePackages.yaml-language-server
          nodePackages.dockerfile-language-server-nodejs
          nodePackages.eslint_d
          nodePackages.prettier
          marksman
          pyright
          python3Packages.black
          python3Packages.isort
          python3Packages.ruff
          shellcheck
          shfmt
          nodePackages.bash-language-server
          rust-analyzer
          
          # PHP und Composer
          php
          phpPackages.composer
          nodePackages.intelephense
          
          # Treesitter benötigt
          tree-sitter
          
          # Zusätzliche Tools
          lazygit
          stylua
          jq
        ]);
        
        # Spezielle LD_LIBRARY_PATH-Einrichtung für bessere Bibliotheksauflösung
        profile = ''
          # Setze LD_LIBRARY_PATH für dynamisch verlinkte Bibliotheken
          export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
            pkgs.glib
            pkgs.ncurses
            pkgs.xorg.libX11
            pkgs.icu
          ]}
          
          # .NET-spezifische Einstellungen
          export DOTNET_ROOT=${pkgs.dotnet-sdk}
          export MSBuildSDKsPath=$DOTNET_ROOT/sdk/$(${pkgs.dotnet-sdk}/bin/dotnet --version)/Sdks
          export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0
        '';
        
        # Ein Skript, das die Neovim-Konfiguration vorbereitet und dann Neovim startet
        runScript = ''
          #!/usr/bin/env bash
          
          # Umgebungsvariablen für separate Konfiguration
          export CONFIG_DIR="$HOME/.config/nvim-dev"
          export DATA_DIR="$HOME/.local/share/nvim-dev"
          export STATE_DIR="$HOME/.local/state/nvim-dev"
          export CACHE_DIR="$HOME/.cache/nvim-dev"
          
          # Verzeichnisse erstellen
          mkdir -p "$CONFIG_DIR/spell" "$DATA_DIR/site/spell" "$STATE_DIR" "$CACHE_DIR"
          
# Im "setup-lazyvim" Teil, ersetze den aktuellen if-Block:

# Prüfe, ob eine Aktualisierung notwendig ist (entweder nicht vorhanden oder veraltet)
          CONFIG_TIMESTAMP="$CONFIG_DIR/.config_timestamp"
          STORE_TIMESTAMP="${lazyvim-config}/.git/HEAD"  # Oder ein anderer zuverlässiger Marker für Änderungen

          if [ ! -f "$CONFIG_TIMESTAMP" ] || \
            [ "$(cat "$CONFIG_TIMESTAMP" 2>/dev/null)" != "$(cat "$STORE_TIMESTAMP" 2>/dev/null)" ]; then
            echo "Aktualisiere LazyVim-Konfiguration..."
            
            # Backup der vorhandenen Konfiguration, falls vorhanden
            if [ -d "$CONFIG_DIR/lua" ]; then
              BACKUP_DIR="$CONFIG_DIR/backup_$(date +%Y%m%d_%H%M%S)"
              mkdir -p "$BACKUP_DIR"
              cp -r "$CONFIG_DIR/lua" "$BACKUP_DIR/" 2>/dev/null || true
              cp "$CONFIG_DIR/init.lua" "$BACKUP_DIR/" 2>/dev/null || true
              echo "Backup der alten Konfiguration erstellt in $BACKUP_DIR"
            fi
            
            # Lösche alte Konfiguration
            rm -rf "$CONFIG_DIR/lua" "$CONFIG_DIR/init.lua" 2>/dev/null || true
            
            # Kopiere die Konfiguration aus dem Nix-Store
            cp -r "${lazyvim-config}/"* "$CONFIG_DIR/" 2>/dev/null || true
            
            # Mache alle Dateien beschreibbar
            find "$CONFIG_DIR" -type f -exec chmod u+w {} \; 2>/dev/null || true
            
            # Aktualisiere den Timestamp-Marker
            cat "$STORE_TIMESTAMP" > "$CONFIG_TIMESTAMP" 2>/dev/null || echo "$(date)" > "$CONFIG_TIMESTAMP"
            
            echo "LazyVim-Konfiguration erfolgreich aktualisiert!"
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
          
          # Mason-Plugin-Konfiguration erstellen
          mkdir -p "$CONFIG_DIR/lua/plugins/nixos"
          cat > "$CONFIG_DIR/lua/plugins/nixos/01-mason.lua" << 'EOF'
return {
  -- Mason konfigurieren - wir deaktivieren es nicht, da einige Plugins es benötigen
  {
    "williamboman/mason.nvim",
    opts = {
      -- Installationspfad außerhalb des Nix-Store
      install_root_dir = vim.fn.stdpath("data") .. "/mason",
    },
  },
}
EOF

          # Init.lua anpassen/erstellen
          cat > "$CONFIG_DIR/init.lua" << 'EOF'
-- XDG-Variablen für separate Konfiguration
vim.env.XDG_DATA_HOME = vim.env.HOME .. "/.local/share/nvim-dev"
vim.env.XDG_STATE_HOME = vim.env.HOME .. "/.local/state/nvim-dev"
vim.env.XDG_CACHE_HOME = vim.env.HOME .. "/.cache/nvim-dev"

-- Stelle sicher, dass diese Konfiguration im Runtimepfad ist
vim.opt.runtimepath:append(vim.env.HOME .. "/.config/nvim-dev")

-- Lazy.nvim-Konfiguration
local lazypath = vim.env.XDG_DATA_HOME .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- LazyVim-Konfiguration laden
require("config.lazy")
EOF

mkdir -p "$CONFIG_DIR"
touch "$CONFIG_DIR/config.yml"
          # Starte Neovim mit der richtigen Konfiguration
          exec env NVIM_APPNAME="nvim-dev" XDG_CONFIG_HOME="$HOME/.config" nvim "$@"
        '';
      };

      # --- Wrapper-Skript für den einfachen Aufruf der FHS-Umgebung ---
      nvim-wrapper = pkgs.writeShellScriptBin "nvim" ''
        exec nvim-fhs "$@"
      '';

    in {
      # Haupt-DevShell für Editor + Sprachen + Tools
      dev = pkgs.mkShell {
        packages = with pkgs; [
          # Nur den FHS-Wrapper und das FHS-Environment
          nvim-wrapper
          neovimFHS
          
          # Basis-Tools außerhalb der FHS-Umgebung
          zsh
          
          # Zusätzliche Tools für die Shell
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
          
          # PHP für die Shell
          php81
          php82
          php83
          php81Packages.composer
          php82Packages.composer
          php83Packages.composer
          php81Packages.phpstan
          php82Packages.phpstan
          php83Packages.phpstan 
          symfony-cli
          
          # DB-Clients für die Shell
          postgresql
          mariadb
          
          # Tools, die keine Probleme mit dynamischen Binaries haben
          lazygit
          ripgrep
          fd
          stylua
          nil
          nixpkgs-fmt
        ];

        shellHook = ''
          echo
          echo "LazyVim DevShell aktiv mit FHS-Umgebung für Neovim."

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

# phpstan für jede PHP-Version
          ln -sf ${pkgs.php81Packages.phpstan}/bin/phpstan $HOME/bin/phpstan-8.1
          ln -sf ${pkgs.php82Packages.phpstan}/bin/phpstan $HOME/bin/phpstan-8.2
          ln -sf ${pkgs.php83Packages.phpstan}/bin/phpstan $HOME/bin/phpstan-8.3
          
          # Standard ist PHP 8.3
          if [ ! -e "$HOME/bin/php" ] || [ ! -e "$HOME/bin/composer" ]|| [ ! -e "$HOME/bin/phpstan" ]; then
            ln -sf $HOME/bin/php-8.3 $HOME/bin/php
            ln -sf $HOME/bin/composer-8.3 $HOME/bin/composer
            ln -sf $HOME/bin/phpstan-8.3 $HOME/bin/phpstan
          fi
          
          # Einfaches Wechsel-Skript erstellen
          cat > $HOME/bin/php-switch <<EOF
          #!/usr/bin/env bash
          if [ "\$1" == "8.1" ] || [ "\$1" == "81" ]; then
            rm -f \$HOME/bin/php \$HOME/bin/composer
            ln -sf \$HOME/bin/php-8.1 \$HOME/bin/php
            ln -sf \$HOME/bin/composer-8.1 \$HOME/bin/composer
            ln -sf \$HOME/bin/phpstan-8.1 \$HOME/bin/phpstan
            echo "PHP 8.1 aktiviert: \$(php -v | head -n 1)"
          elif [ "\$1" == "8.2" ] || [ "\$1" == "82" ]; then
            rm -f \$HOME/bin/php \$HOME/bin/composer
            ln -sf \$HOME/bin/php-8.2 \$HOME/bin/php
            ln -sf \$HOME/bin/composer-8.2 \$HOME/bin/composer
            ln -sf \$HOME/bin/phpstan-8.2 \$HOME/bin/phpstan
            echo "PHP 8.2 aktiviert: \$(php -v | head -n 1)"
          elif [ "\$1" == "8.3" ] || [ "\$1" == "83" ]; then
            rm -f \$HOME/bin/php \$HOME/bin/composer
            ln -sf \$HOME/bin/php-8.3 \$HOME/bin/php
            ln -sf \$HOME/bin/composer-8.3 \$HOME/bin/composer
            ln -sf \$HOME/bin/phpstan-8.3 \$HOME/bin/phpstan
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
          echo "FHS-Umgebung für Neovim aktiviert:"
          echo " - Starte Neovim mit 'nvim' (FHS-Wrapper)"
          echo " - Dynamisch verlinkte Binaries funktionieren innerhalb der FHS-Umgebung"
          echo " - Deine LazyVim-Konfiguration wird automatisch geladen"
          echo
          echo "Ruby:"
          echo "  asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git"
          echo "  asdf install ruby 3.3.4"
          echo "  asdf global ruby 3.3.4"
          echo
          echo "PHP: PHP 8.1-8.3 mit php-switch"
          echo "  Wechseln zwischen Versionen: php-switch 8.1|8.2|8.3"
          echo "  Aktuelle Version: $(php -v | head -n 1)"
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
