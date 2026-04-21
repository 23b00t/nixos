{
  description = "Net-Private MicroVM";

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
        default = self.packages.${system}.net-private;
        net-private = self.nixosConfigurations.net-private.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        net-private = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/common-config.nix
            (
              { config, pkgs, ... }:
              {
                networking.hostName = "net-private-vm";

                services.net-config = {
                  enable = true;
                  index = 6;
                  mac = "00:00:00:00:00:06";
                };
                services.common-config = {
                  enable = true;
                  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDtJWssP02QsNahmgCZDcCOFqSnfwscUUpibbxWAk+ag net-private-vm";
                };
                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
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
                  mem = 2048;
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

                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
