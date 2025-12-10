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
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      index = 1;
      mac = "00:00:00:00:00:01";
    in
    {
      nixpkgs.pkgs = pkgs;
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
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "nvim-vm";

                programs.zsh.enable = true;
                users.defaultUserShell = pkgs.zsh;
                users.groups.user = { };
                users.users.user = {
                  password = "trash";
                  isNormalUser = true;
                  group = "user";
                  extraGroups = [ "wheel" ];
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzJjZw0V2CdaWI/IBFcTQPwQhYtFn/31i5iNPSc1j8G nvim-vm"
                  ];
                  shell = pkgs.zsh;
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = false;
                  };
                };
                microvm = {
                  registerClosure = false;
                  # vsock.cid = 3;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 1028;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 2048;
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
                      source = "/home/nx";
                      mountPoint = "/mnt/host";
                    }
                  ];
                  mem = 8192;
                  vcpu = 2;
                };

                environment.systemPackages = with pkgs; [
                  devenv
                  # lazygit
                  gnupg
                  pinentry-curses
                  gh

                  python3
                  fd
                  unzip

                  gcc
                  gnumake

                  nodejs
                  rustc
                  cargo
                  rust-analyzer
                  watchexec

                  lua-language-server
                  lua51Packages.lua
                  lua51Packages.luarocks
                  nixfmt
                  statix

                  watchman

                  antidote
                  ripgrep
                  fzf
                  oh-my-posh

                  tree-sitter
                  vectorcode

                  nodejs
                  nodePackages.npm

                  (writeShellScriptBin "lazygit" ''
                    export GPG_TTY=$(tty)
                    ${gnupg}/bin/gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
                    exec ${lazygit}/bin/lazygit "$@"
                  '')
                ];

                # for static linked binaries in nvim
                programs.nix-ld.enable = true;

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
                  };

                  histSize = 10000;
                  histFile = "$HOME/.zsh_history";

                  shellInit = ''
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
                    if ! command -v copilot >/dev/null; then
                      npm install -g @github/copilot
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

                systemd.tmpfiles.rules = [
                  # Symlink /etc/zshrc nach /home/user/.zshrc, falls nicht vorhanden
                  "L+ /home/user/.zshrc - - - - /etc/zshrc"
                  "L+ /home/user/.zsh_plugins.txt - - - - /etc/zsh_plugins.txt"
                  "L+ /home/user/.gnupg/gpg-agent.conf - - - - /etc/gpg-agent.conf"
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

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
