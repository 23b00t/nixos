{
  # Use: remote-viewer spice://127.0.0.1:5930 to connect to hyprland
  # nix shell "nixpkgs#virt-viewer"
  description = "Godot MicroVM";

  inputs = {
    microvm = {
      url = "github:microvm-nix/microvm.nix";
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
      index = 13;
      mac = "00:00:00:00:00:0d";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.godot;
        godot = self.nixosConfigurations.godot.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        godot = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhv6q3siBUASk16LN8tCa2nPUp4g2isRuwo1ndDPz7g godot-vm";
            })
            (import ../yazi-config.nix { inherit pkgs; })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "godot-vm";
                nixpkgs.config.allowUnfree = true;

                microvm = {
                  registerClosure = false;
                  hypervisor = "qemu";
                  optimize.enable = false;
                  qemu.extraArgs = [
                    "-display"
                    "none"
                    "-device"
                    "virtio-vga,max_outputs=1"
                    "-device"
                    "qemu-xhci"
                    "-device"
                    "virtio-serial-pci"
                    "-device"
                    "virtio-keyboard-pci"
                    "-device"
                    "virtio-tablet-pci"
                    "-chardev"
                    "spicevmc,id=spicechannel0,name=vdagent"
                    "-device"
                    "virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"
                    # "-device"
                    # "ich9-intel-hda"
                    # "-device"
                    # "hda-duplex"
                    "-spice"
                    "port=5930,addr=127.0.0.1,disable-ticketing=on,image-compression=off,jpeg-wan-compression=never,zlib-glz-wan-compression=never"
                  ];
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 20000;
                    }
                  ];
                  shares = [
                    {
                      proto = "virtiofs";
                      tag = "ro-store";
                      source = "/nix/store";
                      mountPoint = "/nix/.ro-store";
                    }
                  ];
                  devices = [
                    {
                      bus = "pci";
                      path = "0000:02:00.0";
                    }
                    {
                      bus = "pci";
                      path = "0000:02:00.1";
                    }
                  ];
                  mem = 16384;
                  vcpu = 6;
                };

                services.qemuGuest.enable = true;

                # Back to UEFI
                boot.loader.systemd-boot.enable = true;
                boot.loader.efi.canTouchEfiVariables = true;

                # Don't use legacy GRUB in the image
                boot.loader.grub.enable = lib.mkForce false;

                # To fix first startup bug
                boot.kernelParams = [
                  "vfio-pci.disable_idle_d3=1"
                  "nvidia.NVreg_EnableGpuFirmware=0"
                ];
                boot.extraModprobeConfig = ''
                  options vfio-pci disable_idle_d3=1
                '';

                boot.blacklistedKernelModules = [ "nouveau" ];

                hardware.graphics = {
                  enable = true;
                  enable32Bit = true;
                };

                services.xserver.videoDrivers = [ "nvidia" ];

                hardware.nvidia = {
                  modesetting.enable = true;

                  open = true;
                  # forceFullCompositionPipeline = true;
                  package = config.boot.kernelPackages.nvidiaPackages.stable;
                  prime.offload.enable = false;
                  prime.sync.enable = false;
                  nvidiaSettings = true;
                  powerManagement.enable = false;
                  powerManagement.finegrained = false;
                };
                services.getty.autologinUser = "user";

                programs.hyprland = {
                  enable = true;
                  withUWSM = true; # recommended for most users
                  xwayland.enable = true; # Xwayland can be disabled.
                };
                services.spice-vdagentd.enable = true;

                services.greetd = {
                  enable = true;
                  settings = rec {
                    initial_session = {
                      command = "${pkgs.hyprland}/bin/start-hyprland";
                      user = "user";
                    };
                    default_session = initial_session;
                  };
                };

                environment.etc."hyprland.conf".source = ./hypr.conf;

                # for static linked binaries in nvim
                programs.nix-ld.enable = true;
                programs.nix-ld.libraries = with pkgs; [ icu ];

                programs.neovim = {
                  enable = true;
                  defaultEditor = true;
                  withNodeJs = true;
                  withPython3 = true;
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    xdg-utils
                    kitty
                    godot

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

                    firefox

                    (import ../copy-between-vms.nix { inherit pkgs; })
                  ]
                  ++ defaultPkgs;

                users.defaultUserShell = pkgs.zsh;
                users.users.user.shell = pkgs.zsh;

                programs.zsh = {
                  enable = true;
                  enableCompletion = true;
                  autosuggestions.enable = true;
                  syntaxHighlighting.enable = true;

                  shellAliases = {
                    ll = "ls -l";
                    la = "ls -la";
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
                  # hyprland config
                  "L+ /home/user/.config/hypr/hyprland.conf - - - - /etc/hyprland.conf"
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

                services.pulseaudio.enable = false;
                security.rtkit.enable = true;
                services.pipewire = {
                  enable = true;
                  alsa.enable = true;
                  alsa.support32Bit = true;
                  pulse.enable = true;
                };

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
