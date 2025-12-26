{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "nvim MicroVM";

  inputs.microvm = {
    url = "github:astro/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
      index = 1;
      mac = "00:00:00:00:00:01";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.nvim;
        nvim = self.nixosConfigurations.nvim.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        nvim = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzJjZw0V2CdaWI/IBFcTQPwQhYtFn/31i5iNPSc1j8G nvim-vm";
            })
            (import ../yazi-config.nix { inherit pkgs; })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "nvim-vm";

                programs.zsh.enable = true;
                users.defaultUserShell = pkgs.zsh;
                users.users.user.shell = pkgs.zsh;

                microvm = {
                  registerClosure = false;

                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 80000;
                    }
                    {
                      mountPoint = "/var/log";
                      image = "log.img";
                      size = 2048;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 4096;
                    }
                  ];
                  shares = [
                    {
                      proto = "virtiofs";
                      tag = "ro-store";
                      source = "/nix/store";
                      mountPoint = "/nix/.ro-store";
                    }
                    {
                      proto = "virtiofs";
                      tag = "host-home";
                      source = "/home/nx/nixos-config";
                      mountPoint = "/mnt/host";
                    }
                  ];
                  mem = 8192;
                  vcpu = 6;
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    gnupg
                    pinentry-curses
                    gh
                    github-copilot-cli
                    openssl

                    python3
                    fd
                    zip
                    xz
                    unzip
                    p7zip

                    gcc
                    gnumake
                    rustc
                    cargo
                    rust-analyzer
                    watchexec
                    lua-language-server
                    lua51Packages.lua
                    lua51Packages.luarocks
                    nixfmt
                    statix
                    tree-sitter
                    vectorcode
                    nodejs
                    nodePackages.npm
                    watchman
                    icu

                    zellij
                    antidote
                    ripgrep
                    fzf
                    oh-my-posh
                    eza # A modern replacement for ‘ls’
                    zoxide
                    ddate
                    cowsay

                    (writeShellScriptBin "lazygit" ''
                      export GPG_TTY=$(tty)
                      ${gnupg}/bin/gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
                      exec ${lazygit}/bin/lazygit "$@"
                    '')

                    postman
                    dbeaver-bin
                    devenv
                    firefox

                    wprs
                    xwayland

                    (import ../copy-between-vms.nix { inherit pkgs; })
                  ]
                  ++ defaultPkgs;

                networking.firewall = {
                  enable = true;
                  allowedTCPPorts = [
                    8080
                    3000
                  ];
                  allowedTCPPortRanges = [
                    {
                      from = 8500;
                      to = 8523;
                    }
                  ];
                };

                # for static linked binaries in nvim
                programs.nix-ld.enable = true;
                programs.nix-ld.libraries = with pkgs; [ icu ];

                programs.neovim = {
                  enable = true;
                  defaultEditor = true;
                  withNodeJs = true;
                  withPython3 = true;
                };

                # direnv
                programs.direnv = {
                  enable = true;
                  nix-direnv.enable = true;
                };

                programs.zsh = {
                  enableCompletion = true;
                  autosuggestions.enable = true;
                  syntaxHighlighting.enable = true;

                  shellAliases = {
                    ll = "ls -l";
                    la = "ls -la";
                    edit = "sudo -e";
                    sc = "systemctl";
                    dc = "docker compose";
                    ilinit = "$HOME/code/devenv/ilias-devenv/ilias-devenv-builder.sh";
                    n = "nvim";
                  };

                  histSize = 10000;
                  histFile = "$HOME/.zsh_history";

                  shellInit = ''
                    if [[ $- != *i* ]]; then
                      return
                    fi
                    export HISTIGNORE="rm *:cp *"
                    setopt HIST_IGNORE_ALL_DUPS
                    export GPG_TTY=$(tty)

                    # Use antidote plugin manager
                    export ANTIDOTE_HOME="$HOME/.cache/antidote"
                    mkdir -p "$ANTIDOTE_HOME"
                    source ${pkgs.antidote}/share/antidote/antidote.zsh

                    antidote bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.zsh
                    antidote load

                    if command -v oh-my-posh >/dev/null 2>&1; then
                      eval "$(oh-my-posh init zsh --config "$HOME/.cache/oh-my-posh/themes/montys.omp.json")"
                    fi
                  '';
                };

                environment.etc."zsh_plugins.txt".text = ''
                  zsh-users/zsh-autosuggestions
                  zap-zsh/supercharge
                  zsh-users/zsh-syntax-highlighting
                  atoftegaard-git/zsh-omz-autocomplete
                  MichaelAquilina/zsh-you-should-use
                  zap-zsh/magic-enter
                  chivalryq/git-alias
                  zap-zsh/vim
                  zap-zsh/sudo
                  wintermi/zsh-oh-my-posh
                '';

                environment.etc."gpg-agent.conf".text = ''
                  pinentry-program /run/current-system/sw/bin/pinentry-tty
                '';
                environment.etc."zellij".source = ./zellij;
                systemd.tmpfiles.rules = [
                  # Symlink /etc/zshrc nach /home/user/.zshrc, falls nicht vorhanden
                  "L+ /home/user/.zshrc - - - - /etc/zshrc"
                  "L+ /home/user/.zsh_plugins.txt - - - - /etc/zsh_plugins.txt"
                  "L+ /home/user/.gnupg/gpg-agent.conf - - - - /etc/gpg-agent.conf"
                  # zellij config
                  "d /home/user/.config/zellij 0755 user user -"
                  "L+ /home/user/.config/zellij/config.kdl - - - - /etc/zellij/config.kdl"
                  "L+ /home/user/.config/zellij/layouts - - - - /etc/zellij/layouts"
                  "L+ /home/user/.config/zellij/plugins - - - - /etc/zellij/plugins"
                ];

                # git
                programs.git = {
                  enable = true;
                  config = {
                    user = {
                      name = "Daniel Kipp";
                      email = "daniel.kipp@gmail.com";
                    };
                    help.autocorrect = 1;
                    push.default = "simple";
                    pull.rebase = false;
                    "branch \"main\"".mergeoptions = "--no-edit";
                    init.defaultBranch = "main";
                    gpg.program = "gpg";
                    commit.gpgsign = true;
                    user.signingkey = "937A32679620DC68";
                  };
                };

                virtualisation = {
                  docker = {
                    enable = true;
                    # Für rootless Docker (optional)
                    # rootless = {
                    #   enable = true;
                    #   setSocketVariable = true;
                    # };
                    # BuildX-Plugin aktivieren
                    # enableOnBoot = true; # Docker beim Systemstart starten
                    extraOptions = "--experimental"; # Experimentelle Features aktivieren
                    extraPackages = [ pkgs.docker-buildx ]; # BuildX-Plugin hinzufügen
                  };
                  podman = {
                    enable = true;
                    # Keine Docker-Kompatibilität, wenn Docker selbst installiert ist
                    dockerCompat = false;
                  };
                };

                systemd.user.services.wprsd = {
                  description = "wprsd instance";
                  after = [ "network.target" ];
                  serviceConfig = {
                    Type = "simple";
                    Environment = [
                      "PATH=/run/current-system/sw/bin"
                      "RUST_BACKTRACE=1"
                    ];
                    ExecStart = "/run/current-system/sw/bin/wprsd";
                  };
                  wantedBy = [ "default.target" ];
                };

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
