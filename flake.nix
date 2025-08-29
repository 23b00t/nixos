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
          # --- DIE KORREKTUR ---
          # 1. Wir sagen Home-Manager, dass es NICHT die globale Konfiguration verwenden soll.
          home-manager.useGlobalPkgs = false;

          # 2. Wir definieren die Konfiguration für den Benutzer `nx`.
          home-manager.users.nx = {
            # 3. Das ist der korrekte Weg: Wir setzen die `nixpkgs`-Konfiguration
            #    direkt hier. Home-Manager erstellt daraufhin seine eigene,
            #    korrekt konfigurierte `pkgs`-Instanz.
            nixpkgs.config.allowUnfree = true;

            # Der Import deiner home.nix bleibt unverändert.
            imports = [ ./home/home.nix ];
          };

          # Extra-Argumente für Home-Manager-Module
          home-manager.extraSpecialArgs = {
            inherit lazyvim-config;
          };
        }
      ];
    };

    # --- NEU: nur DevShells, berührt NixOS/Home nicht ---
    devShells."x86_64-linux" = let
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = {
          # Global für die Shell erlauben:
          allowUnfree = true;

          # Optional: statt global nur gezielt erlauben (z. B. intelephense)
          # allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
          #   "intelephense"
          # ];
        };
      };
    in {
      # Haupt-DevShell für Editor + Sprachen + Tools
      dev = pkgs.mkShell {
        packages = with pkgs; [
          # Editor + Basics
          neovim zsh lazygit
          git ripgrep fd tree-sitter fzf
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
          update-alternatives
          symfony-cli
          nodePackages.intelephense  # PHP LSP

          # Webserver für Debugging
          php83Packages.php-debug-adapter  # PHP Debugger (xdebug-kompatibel)
          live-server                      # JS/HTML Live-Server

          # Ruby
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

          # Nix LSP und Tools
          nil                        # Nix Language Server
          nixpkgs-fmt               # Nix Formatter

          # DB-Clients
          postgresql
          mariadb

          # Sonstiges nützliches
          lua-language-server
          jq
        ];

        shellHook = ''
          echo
          echo "DevShell aktiv."

          # Oh-My-Posh Theme
          export OMP_CONFIG="''${OMP_CONFIG:-$HOME/.cache/oh-my-posh/themes/amro.omp.json}"

          # PHP mit update-alternatives einrichten
          echo "PHP-Versionen mit update-alternatives einrichten..."
          
          # PHP Binaries
          sudo update-alternatives --remove-all php 2>/dev/null || true
          sudo update-alternatives --install /usr/bin/php php ${pkgs.php81}/bin/php 81
          sudo update-alternatives --install /usr/bin/php php ${pkgs.php82}/bin/php 82
          sudo update-alternatives --install /usr/bin/php php ${pkgs.php83}/bin/php 83
          
          # PHP-FPM
          sudo update-alternatives --remove-all php-fpm 2>/dev/null || true
          sudo update-alternatives --install /usr/bin/php-fpm php-fpm ${pkgs.php81}/bin/php-fpm 81
          sudo update-alternatives --install /usr/bin/php-fpm php-fpm ${pkgs.php82}/bin/php-fpm 82
          sudo update-alternatives --install /usr/bin/php-fpm php-fpm ${pkgs.php83}/bin/php-fpm 83
          
          # Composer
          sudo update-alternatives --remove-all composer 2>/dev/null || true
          sudo update-alternatives --install /usr/bin/composer composer ${pkgs.php81Packages.composer}/bin/composer 81
          sudo update-alternatives --install /usr/bin/composer composer ${pkgs.php82Packages.composer}/bin/composer 82
          sudo update-alternatives --install /usr/bin/composer composer ${pkgs.php83Packages.composer}/bin/composer 83
          
          echo "PHP-Version wechseln mit: sudo update-alternatives --config php"
          echo "PHP-FPM-Version wechseln mit: sudo update-alternatives --config php-fpm"
          echo "Composer-Version wechseln mit: sudo update-alternatives --config composer"
          echo "Aktuelle PHP-Version: $(php -v | head -n 1)"

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

          echo "Ruby:"
          echo "  asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git"
          echo "  asdf install ruby 3.3.4"
          echo "  asdf global ruby 3.3.4"
          echo "PHP: PHP 8.1-8.3 mit update-alternatives"
          echo "  Wechseln zwischen Versionen: sudo update-alternatives --config php"
          echo "  Aktuelle Version: $(php -v | head -n 1)"
          echo "  LSP: intelephense ist im PATH"
          echo
          echo "Nix: LSP (nil) und Formatter (nixpkgs-fmt)"
          echo "  In Neovim: <leader>nf zum Formatieren von Nix-Dateien"
          echo
          echo "Webserver für Debugging:"
          echo "  In Neovim für HTML/PHP/JS-Dateien: <leader>wp startet einen passenden Webserver"
          echo
          echo "JS/TS/HTML/CSS: typescript-language-server, vscode-langservers-extracted, eslint_d, prettier"
          echo "Python: pyright, black, isort, ruff"
          echo "Shell: bash-language-server, shellcheck, shfmt"
          echo "Rust: rustup + rust-analyzer"
          echo "DB-Clients: psql (PostgreSQL), mariadb"
          echo
        '';
      };
    };

      # Separate Shell für Container-Tools (keine Systemänderung)
      containers = pkgs.mkShell {
        packages = with pkgs; [
          docker
          docker-compose
          podman
          podman-compose
          distrobox
        ];
        shellHook = ''
          echo
          echo "Containers-Shell aktiv:"
          echo "  docker, docker-compose, podman, podman-compose, distrobox im PATH."
          echo "  Hinweis: Für lauffähige Daemons Docker/Podman in NixOS aktivieren und Benutzer in 'docker'-Gruppe aufnehmen."
          echo
        '';
      };

      # Alias
      default = self.devShells."x86_64-linux".dev;
    };
  };
}
