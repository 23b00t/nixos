{
  description = "Kali MicroVM";

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
    in
    {
      packages.${system} = {
        default = self.packages.${system}.kali;
        kali = self.nixosConfigurations.kali.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        kali = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/common-config.nix
            ../modules/yazi-config.nix
            ../modules/wprs.nix
            (
              { config, pkgs, ... }:
              {
                services.net-config = {
                  enable = true;
                  index = 8;
                  mac = "00:00:00:00:00:08";
                };
                services.common-config = {
                  enable = true;

                };
                networking.hostName = "kali-vm";

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
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
                  mem = 8192;
                  vcpu = 6;
                };

                virtualisation.podman = {
                  enable = true;
                  dockerCompat = true;
                };

                environment.systemPackages = [
                  pkgs.distrobox
                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
