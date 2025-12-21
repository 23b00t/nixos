{
  description = "Net-Private MicroVM";

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
      index = 6;
      mac = "00:00:00:00:00:06";
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
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDtJWssP02QsNahmgCZDcCOFqSnfwscUUpibbxWAk+ag net-private-vm";
            })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "net-private-vm";

                microvm = {
                  registerClosure = false;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 2048;
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
