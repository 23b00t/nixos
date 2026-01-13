{
  # Use: remote-viewer spice://127.0.0.1:5930 to connect to hyprland
  # nix shell "nixpkgs#virt-viewer"
  description = "godot MicroVM";

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
                  mem = 6144;
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

                systemd.tmpfiles.rules = [
                  "L+ /home/user/.config/hypr/hyprland.conf - - - - /etc/hyprland.conf"
                ];

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
                    lazygit
                    godot
                    (import ../copy-between-vms.nix { inherit pkgs; })
                  ]
                  ++ defaultPkgs;

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
