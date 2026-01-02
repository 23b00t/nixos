{
  description = "steam MicroVM";

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
      index = 12;
      mac = "00:00:00:00:00:12";
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
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/v5mOcbtZ/shL0s5Y2xJYkfEdkPMsznhEC3X7cGgmL steam-vm";
            })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "steam-vm";

                microvm = {
                  registerClosure = false;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "qemu";
                  optimize.enable = false;
                  qemu.machine = "q35";
                  qemu.extraArgs = [
                    "-drive"
                    "if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
                    "-drive"
                    "if=pflash,format=raw,file=/var/lib/microvms/steam/OVMF_VARS.fd"

                    # # USB-Controller
                    # "-device"
                    # "qemu-xhci,id=xhci"
                    #
                    # # USB-Passthrough an den XHCI-Bus
                    # "-device"
                    # "usb-host,vendorid=0x1209,productid=0x2303,bus=xhci.0"
                    # "-device"
                    # "usb-host,vendorid=0x093a,productid=0x2533,bus=xhci.0"
                  ];
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 220000;
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
                  ];
                  devices = [
                    {
                      bus = "pci";
                      path = "0000:02:00.0";
                    } # NVIDIA RTX 5060
                    {
                      bus = "pci";
                      path = "0000:02:00.1";
                    } # NVIDIA Audio
                    # {
                    #   bus = "usb";
                    #   path = "vendorid=0x1209,productid=0x2303";
                    # } # Keyboard 1209:2303
                    # {
                    #   bus = "usb";
                    #   path = "vendorid=0x093a,productid=0x2533";
                    # } # Mouse 093a:2533
                  ];
                  mem = 16384;
                  vcpu = 8;
                };

                systemd.tmpfiles.rules = [
                  "d /var/lib/microvms/steam 0755 microvm kvm -"
                  "C /var/lib/microvms/steam/OVMF_VARS.fd 0640 microvm kvm - ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd"
                  "Z /var/lib/microvms/steam/OVMF_VARS.fd 0640 microvm kvm -"
                ];
                hardware.graphics.enable = true; # Mesa/GL-Stack
                services.xserver.videoDrivers = [ "nvidia" ];
                hardware.nvidia = {
                  open = false;
                  modesetting.enable = true;
                  nvidiaSettings = true;
                  powerManagement.enable = false;
                  powerManagement.finegrained = false;
                };

                programs.hyprland = {
                  enable = true;
                  withUWSM = true;
                  xwayland.enable = true;
                };

                programs.steam = {
                  enable = true;
                  remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
                  dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
                  localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
                };

                environment.systemPackages = [
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
