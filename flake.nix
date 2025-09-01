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

      # --- VERBESSERT: LazyVim-Setup mit Korrektur für dynamisch verlinkte Binaries ---
      devNeovim = pkgs.writeShellScriptBin "nvim" ''
        # Erstelle XDG_CONFIG_HOME, falls es nicht existiert
        TEMP_CONFIG_DIR="$HOME/.config/nvim-dev"
        TEMP_DATA_DIR="$HOME/.local/share/nvim-dev"
        TEMP_STATE_DIR="$HOME/.local/state/nvim-dev"
        TEMP_CACHE_DIR="$HOME/.cache/nvim-dev"
        
        # Erstelle benötigte Verzeichnisse
        mkdir -p "$TEMP_CONFIG_DIR/spell"
        mkdir -p "$TEMP_DATA_DIR/site/spell"
        mkdir -p "$TEMP_STATE_DIR"
        mkdir -p "$TEMP_CACHE_DIR"

        # Überprüfe, ob die Konfiguration bereits kopiert wurde
        CONFIG_MARKER="$TEMP_CONFIG_DIR/.config_copied"
        
        # Kopiere LazyVim-Konfiguration nur, wenn sie noch nicht existiert
        if [ ! -f "$CONFIG_MARKER" ]; then
          echo "Erstelle LazyVim-Konfiguration in $TEMP_CONFIG_DIR..."
          
          # Kopiere die LazyVim-Konfiguration (verwende cp -n, um Überschreiben zu vermeiden)
          cp -rn "${lazyvim-config}/"* "$TEMP_CONFIG_DIR/" 2>/dev/null || true
          
          # Mache alle Dateien beschreibbar
          find "$TEMP_CONFIG_DIR" -type f -exec chmod u+w {} \;
          
          # Kopiere Spell-Dateien aus deiner normalen Neovim-Konfiguration
          SPELL_SOURCE="$HOME/.config/nvim/spell"
          if [ -d "$SPELL_SOURCE" ]; then
            for spell_file in "$SPELL_SOURCE"/*.{spl,sug}; do
              if [ -f "$spell_file" ]; then
                cp -f "$spell_file" "$TEMP_CONFIG_DIR/spell/$(basename "$spell_file")" 2>/dev/null || true
              fi
            done
          fi
          
          # Anpassen der init.lua
          if [ -f "$TEMP_CONFIG_DIR/init.lua" ]; then
            # Mache die Datei beschreibbar
            chmod u+w "$TEMP_CONFIG_DIR/init.lua"
            
            # Erstelle eine temporäre Datei mit unseren Anpassungen
            TMP_INIT=$(mktemp)
            cat > "$TMP_INIT" << 'EOF'
-- Diese Zeilen wurden automatisch von der Nix-DevShell hinzugefügt
vim.env.XDG_DATA_HOME = vim.env.HOME .. "/.local/share/nvim-dev"
vim.env.XDG_STATE_HOME = vim.env.HOME .. "/.local/state/nvim-dev"
vim.env.XDG_CACHE_HOME = vim.env.HOME .. "/.cache/nvim-dev"
vim.opt.runtimepath:append(vim.env.HOME .. "/.config/nvim-dev")

EOF
            # Füge die originale init.lua hinzu
            cat "$TEMP_CONFIG_DIR/init.lua" >> "$TMP_INIT"
            # Ersetze die originale init.lua ohne Nachfrage
            mv -f "$TMP_INIT" "$TEMP_CONFIG_DIR/init.lua"
            chmod u+w "$TEMP_CONFIG_DIR/init.lua"
          else
            # Erstelle eine neue init.lua
            cat > "$TEMP_CONFIG_DIR/init.lua" << 'EOF'
-- Diese init.lua lädt deine LazyVim-Konfiguration
-- Setze XDG-Variablen, damit Plugins in der devShell installiert werden
vim.env.XDG_DATA_HOME = vim.env.HOME .. "/.local/share/nvim-dev"
vim.env.XDG_STATE_HOME = vim.env.HOME .. "/.local/state/nvim-dev"
vim.env.XDG_CACHE_HOME = vim.env.HOME .. "/.cache/nvim-dev"

-- Stelle sicher, dass Spell-Dateien gefunden werden
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
          fi
          
          # Marker setzen, dass die Konfiguration kopiert wurde
          touch "$CONFIG_MARKER"
          
          echo "LazyVim-Konfiguration erfolgreich erstellt."
        fi

        # --- VERBESSERT: FHS-Wrapper für dynamisch verlinkte Binaries wie markdown-preview ---
        # Erstelle ein generelles FHS-Wrapper-Skript für alle dynamisch verlinkten Binaries
        FHS_WRAPPER="$HOME/bin/nix-fhs-run"
        if [ ! -f "$FHS_WRAPPER" ]; then
          mkdir -p "$HOME/bin"
          cat > "$FHS_WRAPPER" << 'EOF'
#!/usr/bin/env bash
# FHS-Wrapper für dynamisch verlinkte Binaries unter NixOS

# Füge wichtige Bibliotheken zum LD_LIBRARY_PATH hinzu
export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.glib}/lib:${pkgs.zlib}/lib:${pkgs.ncurses}/lib:$LD_LIBRARY_PATH

# Führe die Binary mit den richtigen Umgebungsvariablen aus
exec "$@"
EOF
          chmod +x "$FHS_WRAPPER"
        fi

        # Prüfe nach Markdown-Preview und andere problematische Binaries
        process_bin() {
          local bin_path="$1"
          
          # Überprüfe, ob die Binary existiert und ausführbar ist
          if [ -f "$bin_path" ] && [ -x "$bin_path" ]; then
            # Erstelle einen Wrapper, wenn er noch nicht existiert
            if [ ! -f "$bin_path.wrapped" ]; then
              # Sichere die Original-Binary
              cp "$bin_path" "$bin_path.original"
              
              # Erstelle einen Wrapper-Skript
              cat > "$bin_path" << EOF
#!/usr/bin/env bash
# Automatisch generierter FHS-Wrapper für $(basename "$bin_path")
$FHS_WRAPPER "$bin_path.original" "\$@"
EOF
              chmod +x "$bin_path"
              
              # Setze Marker, dass die Binary gewrappt wurde
              touch "$bin_path.wrapped"
              
              echo "Binary gewrappt: $bin_path"
            fi
          fi
        }

        # Suche nach allen Binaries in Markdown-Preview und patche sie
        LAZY_DIR="$TEMP_DATA_DIR/lazy"
        if [ -d "$LAZY_DIR" ]; then
          echo "Prüfe auf dynamisch verlinkte Binaries in Plugins..."
          # Markdown-Preview spezifisch
          if [ -d "$LAZY_DIR/markdown-preview.nvim" ]; then
            MP_BIN="$LAZY_DIR/markdown-preview.nvim/app/bin/markdown-preview-linux"
            process_bin "$MP_BIN"
          fi
          
          # Nach anderen ausführbaren Binaries in Plugin-Verzeichnissen suchen
          find "$LAZY_DIR" -type f -executable -not -name "*.sh" -not -name "*.wrapped" -not -name "*.original" | while read -r bin; do
            # Prüfe, ob es sich um eine ELF-Binary handelt
            if file "$bin" | grep -q "ELF"; then
              process_bin "$bin"
            fi
          done
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
          
          # Tools zur Binary-Modifikation
          patchelf
          
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
          echo "LazyVim-Konfiguration: Deine eigene Konfiguration aus 23b00t/lazyvim wird verwendet."
          echo "Dynamisch verlinkte Binaries werden automatisch gewrappt."
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
