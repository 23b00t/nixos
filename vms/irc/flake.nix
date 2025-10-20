{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "IRC MicroVM";

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
      index = 5;
      mac = "00:00:00:00:00:05";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.net-vm;
        net-vm = self.nixosConfigurations.net-vm.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        net-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ./net-config.nix { inherit lib index mac; })
            (
              { config, ... }:
              {
                networking.hostName = "irc-vm";

                users.groups.irc = { };
                users.users.irc = {
                  isNormalUser = true;
                  group = "irc";
                  extraGroups = [ "wheel" ];
                };
                services.getty.autologinUser = "irc";
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                microvm = {
                  # microvm.vsock.cid;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/var";
                      image = "var.img";
                      size = 8192;
                    }
                    {
                      mountPoint = "/home/irc";
                      image = "home.img";
                      size = 8192;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 8192;
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
                  mem = 4096;
                };

                environment.systemPackages = with pkgs; [
                  tiny
                ];
                system.stateVersion = "25.11";
              }
            )
          ];
        };
      };
    };
}
