{
  description = "Net MicroVM";

  inputs = {
    microvm = {
      url = "github:astro/microvm.nix";
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
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
      index = 5;
      mac = "00:00:00:00:00:05";
      sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1NctcWQx10E7C96SSb9LSDqFln/7g82rFnRfsPLpFX net-vm";
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
            ../net-config.nix
            ../common-config.nix
            ../zen-firefox.nix
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "net-vm";

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
                    {
                      mountPoint = "/var/log";
                      image = "log.img";
                      size = 1028;
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
                  mem = 4048;
                  vcpu = 4;
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
          specialArgs = {
            inherit
              inputs
              lib
              pkgs
              index
              mac
              sshKey
              ;
          };
        };
      };
    };
}
