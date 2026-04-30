{
  description = "Net MicroVM";

  inputs = {
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
      zen-browser,
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        default = self.packages.${system}.net;
        net = self.nixosConfigurations.net.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        net = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/common-config.nix
            (
              { config, pkgs, ... }:
              {
                networking.hostName = "net-vm";

                services.net-config = {
                  enable = true;
                  index = 5;
                  mac = "00:00:00:00:00:05";
                };
                services.common-config = {
                  enable = true;
                  
                };

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 10000;
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
                  mem = 6144;
                  vcpu = 2;
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

                # TODO: Mangage extensions declerativly by policies
                programs = {
                  firefox = {
                    enable = true;
                    languagePacks = [
                      "de"
                      "en-US"
                    ];
                  };
                };

                environment.systemPackages = [
                  pkgs.wprs
                  pkgs.xwayland
                  (import ../zen-firefox.nix { inherit lib pkgs zen-browser; })

                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
