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
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "nvim-vm";

                programs.zsh.enable = true;
                users.defaultUserShell = pkgs.zsh;
                users.groups.users = { };
                users.users.user = {
                  password = "trash";
                  isNormalUser = true;
                  group = "users";
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
                      mountPoint = "/var/log";
                      image = "log.img";
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

                time.timeZone = "Europe/Berlin";
                environment.systemPackages = with pkgs; [
                  gnupg
                  pinentry-curses
                  gh
                  github-copilot-cli

                  python3
                  fd
                  unzip

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
                  cowsay

                  (import ../copy-between-vms.nix { inherit pkgs; })
                ];
                programs.yazi = {
                  enable = true;
                  plugins = {
                    inherit (pkgs.yaziPlugins)
                      git
                      chmod
                      mount
                      full-border
                      jump-to-char
                      compress
                      smart-paste
                      yatline-catppuccin
                      ;
                  };
                  settings = {
                    yazi = {
                      mgr = {
                        linemode = "size";
                        show_hidden = true;
                      };
                      plugin = {
                        prepend_fetchers = [
                          {
                            id = "git";
                            name = "*";
                            run = "git";
                          }
                          {
                            id = "git";
                            name = "*/";
                            run = "git";
                          }
                        ];
                      };
                    };
                    keymap = {
                      mgr = {
                        prepend_keymap = [
                          {
                            desc = "Maximize or restore the preview pane";
                            on = "M";
                            run = "plugin mount";
                          }
                          {
                            desc = "Chmod on selected files";
                            on = [
                              "c"
                              "m"
                            ];
                            run = "plugin chmod";
                          }
                          {
                            desc = "Jump to char";
                            on = "F";
                            run = "plugin jump-to-char";
                          }
                          {
                            desc = "Compress selected files";
                            on = "z";
                            run = "plugin compress";
                          }
                          {
                            desc = "Smart Paste (context-aware paste)";
                            on = "P";
                            run = "plugin smart-paste";
                          }
                        ];
                      };
                    };
                  };
                  flavors = {
                    inherit (pkgs.yaziPlugins) yatline-catppuccin;
                  };
                  initLua = builtins.toFile "init.lua" ''
                    require("full-border"):setup()
                    require("git"):setup()
                  '';
                };
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

                environment.etc."init.lua".text = ''
                  require("full-border"):setup()
                  require("git"):setup()
                '';

                environment.etc."ssh_config".text = ''
                  Host *
                      StrictHostKeyChecking no
                      UserKnownHostsFile /dev/null
                '';

                systemd.tmpfiles.rules = [
                  # Symlink /etc/zshrc nach /home/user/.zshrc, falls nicht vorhanden
                  "L+ /home/user/.zshrc - - - - /etc/zshrc"
                  "L+ /home/user/.zsh_plugins.txt - - - - /etc/zsh_plugins.txt"
                  "L+ /home/user/.gnupg/gpg-agent.conf - - - - /etc/gpg-agent.conf"
                  "L+ /home/user/.config/yazi/init.lua - - - - /etc/init.lua"
                  "L+ /home/user/.ssh/config - - - - /etc/ssh_config"
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
