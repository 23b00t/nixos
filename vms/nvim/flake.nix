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
                    PasswordAuthentication = true;
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
                    # {
                    #   proto = "virtiofs";
                    #   tag = "home";
                    #   source = "/home/nx";
                    #   mountPoint = "/home/nvim";
                    # }
                  ];
                  mem = 4096;
                };

                environment.systemPackages = with pkgs; [
                  devenv
                  lazygit
                  gnupg
                  pinentry-curses
                  gh
                  gh-copilot

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
                ];

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
                    cmd = "eval $(fzf < ~/nixos-config/home/cmds)";
                    pcmd = "cmd=$(fzf < ~/nixos-config/home/cmds); vared -p '> ' -c cmd; eval '$cmd'";
                    n = "nvim";
                    dc = "docker compose";
                    kk = "kitty @ kitten";
                    ilinit = "$HOME/nixos-config/devenv/ilias-devenv/ilias-devenv-builder.sh";
                  };

                  histSize = 10000;
                  histFile = "$HOME/.zsh_history";

                  shellInit = ''
                    export HISTIGNORE="rm *:cp *"
                    setopt HIST_IGNORE_ALL_DUPS
                    # Use antidote plugin manager
                    export ANTIDOTE_HOME="$HOME/.cache/antidote"
                    mkdir -p "$ANTIDOTE_HOME"
                    source ${pkgs.antidote}/share/antidote/antidote.zsh

                    # Plugins laden
                    antidote bundle <<EOPLUGINS
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
                    kutsan/zsh-system-clipboard
                    EOPLUGINS

                    antidote load
                    if command -v oh-my-posh >/dev/null 2>&1; then
                      eval "$(oh-my-posh init zsh --config "$HOME/.cache/oh-my-posh/themes/slimfat.omp.json")"
                    fi
                    # GitHub Copilot CLI Aliases
                    if command -v ${pkgs.gh}/bin/gh >/dev/null 2>&1; then
                      eval "$(${pkgs.gh}/bin/gh copilot alias -- zsh)"
                    fi
                    if command -v zoxide >/dev/null 2>&1; then
                      eval "$(zoxide init zsh)"
                    fi
                    if command -v gh >/dev/null 2>&1; then
                      gh extension install github/gh-copilot || true
                    fi
                  '';
                };

                # Set up gh config for the user
                environment.etc."gh-config.yml".text = ''
                  git_protocol: ssh
                '';

                systemd.tmpfiles.rules = [
                  # Symlink to user's config directory (for user 'user')
                  "L+ /home/user/.config/gh/config.yml - - - - /etc/gh-config.yml"
                  # Symlink /etc/zshrc nach /home/user/.zshrc, falls nicht vorhanden
                  "L+ /home/user/.zshrc - - - - /etc/zshrc"
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
