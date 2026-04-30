{
  description = "test MicroVM";

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
        default = self.packages.${system}.test;
        test = self.nixosConfigurations.test.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        test = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/ide.nix
            ../modules/zsh.nix
            ../modules/persistent-store-overlay.nix
            ../modules/common-config.nix
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "test-vm";

                services.net-config = {
                  enable = true;
                  index = 3;
                  mac = "00:00:00:00:00:03";
                };
                services.common-config = {
                  enable = true;
                  
                };
                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 8000;
                    }
                  ];
                  mem = 8192;
                  vcpu = 4;
                };

                environment.systemPackages = with pkgs; [
                  devenv
                ];

                services.ide = {
                  enable = true;
                };

                services.zsh-env = {
                  enable = true;
                };

                services.persistentStoreOverlay = {
                  enable = true;
                };

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
