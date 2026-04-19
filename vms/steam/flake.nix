# INFO: Grafic problems solved with the following beta driver:
# Sun Jan 18 10:25:53 2026
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 590.48.01              Driver Version: 590.48.01      CUDA Version: 13.1     |
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
                    "10,sockets=1,cores=10,threads=1"
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
                  vcpu = 10;
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
                  "nvidia-drm.modeset=1"
                  # "nvidia.NVreg_EnableGpuFirmware=0"
                ];
                boot.extraModprobeConfig = ''
                  options vfio-pci disable_idle_d3=1
                  options nvidia-drm modeset=1 fbdev=1
                '';
               
                boot.blacklistedKernelModules = [ "nouveau" ];

                boot.kernelPackages = pkgs.linuxPackages_zen;

                hardware.graphics = {
                  enable = true;
                  enable32Bit = true;
                };

                services.xserver.videoDrivers = [ "nvidia" ];

                hardware.nvidia = {
                  modesetting.enable = true;
                  open = true;

                  package = config.boot.kernelPackages.nvidiaPackages.beta;
                  prime.offload.enable = false;
                  prime.sync.enable = false;
                  nvidiaSettings = true;
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
                environment.loginShellInit = ''
                  if [[ "$(tty)" = "/dev/tty1" ]]; then
                    # mkdir -p "$HOME/.local/state"
                    # exec > >(tee -a "$HOME/.local/state/steam-autostart.log") 2>&1
                    set -x
                    exec "$HOME/gs.sh"
                  fi
                '';

                environment.etc."gs.sh" = {
                  mode = "0755";
                  text = ''
                    #!/usr/bin/env bash
                    set -xeuo pipefail

                    MAXMODE=$(head -1 /sys/class/drm/card0-HDMI-A-1/modes)
                    if [[ "$MAXMODE" == "1920x1080" ]]; then
                      DEVICE_TYPE="monitor"
                    else
                      DEVICE_TYPE="tv"
                    fi

                    if [[ "$DEVICE_TYPE" == "monitor" ]]; then
                      gamescopeArgs=(
                        --adaptive-sync # VRR support
                        # --hdr-enabled
                        --mangoapp # performance overlay
                        --rt
                        --steam
                        --backend drm
                        # -W 1920 -H 1080 -w 1920 -h 1080
                        --immediate-flips
                        # -r 60
                        # --xwayland-count 2
                        # --framerate-limit 60
                      )
                    else
                      gamescopeArgs=(
                        --adaptive-sync
                        --hdr-enabled
                        --mangoapp
                        --rt
                        --steam
                        --backend drm
                        -W 3840 -H 2160 -w 3840 -h 2160
                        --immediate-flips
                      )
                    fi
                    steamArgs=(
                      # -pipewire-dmabuf
                      -steamdeck
                      -steamos3
                    )

                    export GAMESCOPE_LAYER_FORCE_NO_GAMMA=1
                    export VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json"
                    export LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri
                    export __GLX_VENDOR_LIBRARY_NAME=nvidia
                    export GAMESCOPE_DISABLE_HARDWARE_CURSOR=1

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

                environment.systemPackages = with pkgs; [
                  mangohud
                  pciutils
                  dbus
                  vim
                  btop

                  protonup-rs
                  # mesa
                  # mesa-demos # für glxinfo, glxgears
                  # vulkan-tools # für vulkaninfo
                  # vulkan-loader
                  # vulkan-validation-layers

                ];
                services.dbus.enable = true;

                networking.networkmanager.enable = true;
                networking.networkmanager.settings = {
                  main.no-auto-default = "*";
                };

                services.upower.enable = true;

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

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
