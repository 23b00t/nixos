{
  description = "steam MicroVM";

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
      index = 12;
      mac = "00:00:00:00:00:0c";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.steam;
        steam = self.nixosConfigurations.steam.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        steam = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "steam-vm";

                microvm = {
                  registerClosure = false;

                  hypervisor = "qemu";
                  optimize.enable = false;
                  qemu.extraArgs = [
                    "-smp"
                    "8,sockets=1,cores=8,threads=1"
                    "-mem-prealloc"
                  ];
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 220000;
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
                    # Mouse
                    {
                      bus = "usb";
                      path = "vendorid=0x093a,productid=0x2533";
                    }
                    # Keyboard (Atreus)
                    {
                      bus = "usb";
                      path = "vendorid=0x1209,productid=0x2303";
                    }

                    # AX211 Bluetooth
                    {
                      bus = "usb";
                      path = "vendorid=0x8087,productid=0x0033";
                    }
                  ];
                  mem = 16384;
                  vcpu = 8;
                };

                services.qemuGuest.enable = true;

                # Back to UEFI
                boot.loader.systemd-boot.enable = true;
                boot.loader.efi.canTouchEfiVariables = true;

                # Don't use legacy GRUB in the image
                boot.loader.grub.enable = lib.mkForce false;
                # services.power-profiles-daemon.enable = true;
                # powerManagement.cpuFreqGovernor = "performance";

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
                  nvidiaSettings = false;
                  powerManagement.enable = false;
                  powerManagement.finegrained = false;
                };

                programs.gamescope = {
                  enable = true;
                  capSysNice = true;
                };

                programs.steam = {
                  enable = true;
                  remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
                  dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
                  localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
                  gamescopeSession.enable = true;
                };

                programs.gamemode.enable = true;

                services.getty.autologinUser = "user";

                # environment.sessionVariables = {
                #   WLR_NO_HARDWARE_CURSORS = "1";
                #   NIXOS_OZONE_WL = "1";
                # };
                # seatd für gamescope
                services.seatd = {
                  enable = true;
                  group = "seat";
                };

                # security.wrappers.bwrap = {
                #   owner = "root";
                #   group = "root";
                #   setuid = true;
                #   source = "${pkgs.bubblewrap}/bin/bwrap";
                # };

                # tty1 nicht von getty belegen lassen
                # systemd.services."getty@tty1".enable = false;
                # environment.loginShellInit = ''
                #   if [[ "$(tty)" = "/dev/tty1" ]]; then
                #     mkdir -p "$HOME/.local/state"
                #     exec > >(tee -a "$HOME/.local/state/steam-autostart.log") 2>&1
                #     set -x
                #     exec "$HOME/gs.sh"
                #   fi
                # '';

                environment.etc."gs.sh" = {
                  mode = "0755";
                  text = ''
                    #!/usr/bin/env bash
                    set -xeuo pipefail

                    gamescopeArgs=(
                        --adaptive-sync # VRR support
                        # --hdr-enabled
                        --mangoapp # performance overlay
                        --rt
                        --steam
                        # --framerate-limit 60
                    )
                    steamArgs=(
                        -pipewire-dmabuf
                        -tenfoot
                    )
                    exec dbus-run-session -- gamescope "''${gamescopeArgs[@]}" -- steam "''${steamArgs[@]}"
                  '';
                };

                # services.udev.extraRules = ''
                #   KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
                # '';

                systemd.tmpfiles.rules = [
                  "L+ /home/user/gs.sh - - - - /etc/gs.sh"
                  "L+ /home/user/.ssh/config - - - - /etc/ssh_config"
                ];

                # programs.nix-ld.enable = true;
                # programs.nix-ld.libraries = with pkgs; [
                #   stdenv.cc.cc # libstdc++.so, libgcc_s.so, libc.so, etc.
                #   zlib # Komprimierung
                #   icu # Unicode/Internationale Zeichen - wie von dir genannt
                #   expat # XML-Parsing (Steam selbst, Proton, Wine, viele Launcher)
                #   openssl # OpenSSL (TLS/SSL)
                #   curl # (manchmal für Netzwerk-Downloads)
                #   pulseaudio # für Audio in vielen Games/Proton
                #   alsa-lib # für direkten ALSA-Support
                #   dbus # für Steam-GUI, Overlay, Controller, Proton
                #
                #   mesa # libGL, libEGL, Mesa-GL-Implementierungen
                #   libglvnd # GL/Vulkan-Dispatch (klüger als einzelne libGL)
                #   vulkan-loader # libvulkan.so Loader
                #   vulkan-headers # oft von Spielen benötigt (Header werden von Binär-Dists mitgeladen)
                #
                #   libvorbis # viele Spiele verwenden OGG/Opus-Audio
                #   libogg
                #   libopus
                #
                #   libpng # viele GUIs/Games/Tools für PNG-Support
                #   libjpeg
                #   fontconfig # Fonts/DPI/Fallback etc.
                #   freetype # Spiele ohne fontconfig
                #   libuuid # IDs, oft bei Games & Launcher im Backend
                #   libxcb # X11 (für Fenstermodus, Overlay, XWayland)
                #   xorg.libX11
                #   xorg.libXext
                #   xorg.libXrandr
                #   xorg.libXcursor
                #   xorg.libXi
                #   xorg.libXtst
                #   xorg.libXinerama
                #   xorg.libXScrnSaver
                #
                #   glib # GObject/GTK-Basics
                #   gtk3
                # ];
                environment.systemPackages = with pkgs; [
                  mangohud
                  pciutils
                  dbus
                  vim
                  btop
                  # mesa
                  # mesa-demos # für glxinfo, glxgears
                  # vulkan-tools # für vulkaninfo
                  # vulkan-loader
                  # vulkan-validation-layers
                  (import ../copy-between-vms.nix { inherit pkgs; })
                ];
                services.dbus.enable = true;

                networking.networkmanager.enable = true;
                networking.networkmanager.settings = {
                  main.no-auto-default = "*";
                };

                services.upower.enable = true;

                # time.timeZone = "Europe/Berlin";
                # i18n.defaultLocale = "en_US.UTF-8";
                # i18n.extraLocaleSettings = {
                #   LC_TIME = "de_DE.UTF-8";
                #   LC_MONETARY = "de_DE.UTF-8";
                #   LC_NUMERIC = "de_DE.UTF-8";
                #   LC_MEASUREMENT = "de_DE.UTF-8";
                #   LC_PAPER = "de_DE.UTF-8";
                #   LC_ADDRESS = "de_DE.UTF-8";
                #   LC_TELEPHONE = "de_DE.UTF-8";
                #   LC_NAME = "de_DE.UTF-8";
                #   LC_IDENTIFICATION = "de_DE.UTF-8";
                # };

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = false;
                  };
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };
                users.groups.users = { };
                users.groups.seat = { };

                users.users.user = {
                  isNormalUser = true;
                  group = "users";
                  extraGroups = [
                    "wheel"
                    "seat"
                    "video"
                    "render"
                    "input"
                  ];
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/v5mOcbtZ/shL0s5Y2xJYkfEdkPMsznhEC3X7cGgmL steam-vm"
                  ];
                };

                environment.etc."ssh_config".text = ''
                  Host *
                      StrictHostKeyChecking no
                      UserKnownHostsFile /dev/null
                  Host 10.0.0.254 
                      IdentitiesOnly yes
                '';

                # NOTE: connect controller via ssh:
                # bluetoothctl
                # power on
                # agent on
                # default-agent
                # scan on
                # pair AA:BB:CC:DD:EE:FF
                # trust AA:BB:CC:DD:EE:FF
                # connect AA:BB:CC:DD:EE:FF
                #
                services.blueman.enable = true;
                hardware.bluetooth = {
                  enable = true;
                  settings = {
                    General = {
                      AutoEnable = true;
                      FastConnectable = true;
                    };
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

                environment.sessionVariables = {
                  # Solves bug with hosts xterm-kitty handed to the vms
                  TERM = "xterm-256color";
                };

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
