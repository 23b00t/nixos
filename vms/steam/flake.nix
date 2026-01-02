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
                    {
                      bus = "usb";
                      path = "vendorid=0x1209,productid=0x2303";
                    } # Keyboard 1209:2303
                    {
                      bus = "usb";
                      path = "vendorid=0x093a,productid=0x2533";
                    } # Mouse 093a:2533
                  ];
                  mem = 16384;
                  vcpu = 8;
                };
                hardware.opengl.enable = true; # Mesa/GL-Stack
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
