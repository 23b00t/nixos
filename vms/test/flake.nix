{
  description = "test MicroVM";

  inputs = {
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      index = 3;
      mac = "00:00:00:00:00:03";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.test;
        test = self.nixosConfigurations.test.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        test = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2091GSIL+SlR1BsWswg+6DZzrL+enxmXo74d/OSUwv test-vm";
            })
            (import ../yazi-config.nix { inherit pkgs; })
            (import ../rdp.nix { inherit lib; })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "test-vm";

                programs.zsh.enable = true;
                users.defaultUserShell = pkgs.zsh;
                users.users.user.shell = pkgs.zsh;

                microvm = {
                  registerClosure = false;

                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  # volumes = [
                  #   {
                  #     mountPoint = "/home/user";
                  #     image = "home.img";
                  #     size = 10000;
                  #   }
                  #   {
                  #     mountPoint = "/var/log";
                  #     image = "log.img";
                  #     size = 1028;
                  #   }
                  #   {
                  #     image = "nix-store-overlay.img";
                  #     mountPoint = config.microvm.writableStoreOverlay;
                  #     size = 2048;
                  #   }
                  # ];
                  # shares = [
                  #   {
                  #     proto = "virtiofs";
                  #     tag = "ro-store";
                  #     source = "/nix/store";
                  #     mountPoint = "/nix/.ro-store";
                  #   }
                  # ];
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

                    godot_4

                    wprs
                    xwayland

                    (import ../copy-between-vms.nix { inherit pkgs; })
                  ]
                  ++ defaultPkgs;

                # for static linked binaries in nvim
                programs.nix-ld.enable = true;
                programs.nix-ld.libraries = with pkgs; [ icu ];

                programs.neovim = {
                  enable = true;
                  defaultEditor = true;
                  withNodeJs = true;
                  withPython3 = true;
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
