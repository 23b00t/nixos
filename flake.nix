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
          neovim
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

          # PHP Tooling + Versioning
          phpPackages.composer
          symfony-cli
          asdf-vm                 # für PHP-Versionen via asdf-Plugin
          nodePackages.intelephense  # PHP LSP (empfohlen statt phpactor)

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

          # asdf korrekt initialisieren (Nix-Paketpfad + Home-Datenverzeichnis)
          export ASDF_DIR="${pkgs.asdf-vm}/share/asdf-vm"
          export ASDF_DATA_DIR="$HOME/.asdf"
          if [ -f "$ASDF_DIR/asdf.sh" ]; then
            . "$ASDF_DIR/asdf.sh"
          fi
          # Shims sicher in den PATH (falls asdf.sh das nicht schon getan hat)
          export PATH="$ASDF_DATA_DIR/shims:$PATH"

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
          echo "  In deinem Gemfile (group :development): gem 'ruby-lsp'; gem 'solargraph'; dann 'bundle install'"
          echo
          echo "PHP:"
          echo "  asdf plugin add php https://github.com/asdf-community/asdf-php.git"
          echo "  asdf install php 8.3.12 && asdf global php 8.3.12"
          echo "  LSP: intelephense ist im PATH"
          echo
          echo "JS/TS/HTML/CSS: typescript-language-server, vscode-langservers-extracted, eslint_d, prettier"
          echo "Python: pyright, black, isort, ruff"
          echo "Shell: bash-language-server, shellcheck, shfmt"
          echo "Rust: rustup + rust-analyzer"
          echo "DB-Clients: psql (PostgreSQL), mariadb"
          echo
        '';
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
