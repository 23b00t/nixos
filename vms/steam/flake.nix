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
      vmRegistry = import ../registry.nix;
      usb = vmRegistry.hardware.usb.byName;
      allowedUsbDevices = vmRegistry.hardware.usb.allowedForOwner "steam";
      bluetoothUsbDevice = usb."bluetooth-ax211";
      steamUsbDevices = builtins.filter (
        device: builtins.elem device.name [
          "mouse-main"
          "keyboard-atreus"
          bluetoothUsbDevice.name
        ]
      ) allowedUsbDevices;
      gpuPciPaths = vmRegistry.hardware.pci.devicePaths.gpu or [ ];
      mkUsbDevice = device: {
        bus = "usb";
        path = device.microvmUsbPath;
      };
      mkPciDevice = path: {
        bus = "pci";
        inherit path;
      };
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
            ../modules/net-config.nix
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "steam-vm";
                services.net-config = {
                  enable = true;
                  index = 12;
                  mac = "00:00:00:00:00:0c";
                };

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
                  devices = (map mkPciDevice gpuPciPaths) ++ map mkUsbDevice steamUsbDevices;
                  mem = 16384;
                  vcpu = 10;
                };

                services.qemuGuest.enable = true;

                # Back to UEFI
                boot.loader.systemd-boot.enable = true;
                boot.loader.efi.canTouchEfiVariables = true;

                # Don't use legacy GRUB in the image
                boot.loader.grub.enable = lib.mkForce false;

                # To fix first startup bug / PCI BAR allocation issues
                boot.kernelParams = [
                  "vfio-pci.disable_idle_d3=1"
                  "nvidia-drm.modeset=1"
                  "pci=realloc=on"
                  "pci=assign-busses"
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

                  package = config.boot.kernelPackages.nvidiaPackages.stable;
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

                    # export GAMESCOPE_LAYER_FORCE_NO_GAMMA=1
                    # export LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri
                    export __GLX_VENDOR_LIBRARY_NAME=nvidia
                    # export GAMESCOPE_DISABLE_HARDWARE_CURSOR=1

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

# Teste vor dem ersten VM-Start:
# - `sudo chgrp kvm /dev/vfio/15`
# - `sudo chmod 660 /dev/vfio/15`
# Minimal imperative VFIO rebind/reset (before first Steam VM boot)

# ```bash
# # 1) Ensure vfio-pci is loaded
# sudo modprobe vfio-pci
#
# # 2) Rebind GPU + GPU-audio to vfio-pci
# for dev in 0000:02:00.0 0000:02:00.1; do
#   [ -e /sys/bus/pci/devices/$dev ] || continue
#   echo vfio-pci | sudo tee /sys/bus/pci/devices/$dev/driver_override >/dev/null
#   if [ -L /sys/bus/pci/devices/$dev/driver ]; then
#     echo $dev | sudo tee /sys/bus/pci/devices/$dev/driver/unbind >/dev/null
#   fi
#   echo $dev | sudo tee /sys/bus/pci/drivers/vfio-pci/bind >/dev/null
# done
#
# # 3) Function reset (if available)
# [ -w /sys/bus/pci/devices/0000:02:00.0/reset ] && echo 1 | sudo tee /sys/bus/pci/devices/0000:02:00.0/reset >/dev/null
# [ -w /sys/bus/pci/devices/0000:02:00.1/reset ] && echo 1 | sudo tee /sys/bus/pci/devices/0000:02:00.1/reset >/dev/null
#
# # 4) Optional fallback: upstream bridge reset
# [ -w /sys/bus/pci/devices/0000:00:01.1/reset ] && echo 1 | sudo tee /sys/bus/pci/devices/0000:00:01.1/reset >/dev/null
#
# # 5) Brief wait, then start VM
# sleep 2
# sudo systemctl restart microvm@steam
# ```

