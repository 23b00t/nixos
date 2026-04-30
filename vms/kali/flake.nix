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
            (
              { config, pkgs, ... }:
              let

              in
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
                  optimize.enable = false;
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

                systemd.user.services.wprsd = {
                  description = "wprsd instance";
                  after = [ "network.target" ];
                  serviceConfig = {
                    Type = "simple";
                    Environment = [
                      "PATH=/run/current-system/sw/bin"
                      "RUST_BACKTRACE=1"
                    ];
                    ExecStart = "/run/current-system/sw/bin/wprsd";
                  };
                  wantedBy = [ "default.target" ];
                };

                virtualisation.podman = {
                  enable = true;
                  dockerCompat = true;
                };

                environment.systemPackages = [
                  pkgs.distrobox
                  pkgs.wprs
                  pkgs.xwayland

                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
