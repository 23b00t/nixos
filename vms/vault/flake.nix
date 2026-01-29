{
  description = "Vault MicroVM";

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
      index = 10;
      mac = "00:00:00:00:00:0a";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.vault;
        vault = self.nixosConfigurations.vault.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        vault = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINPbWqbgvB7bf39HteuS/bmSDqLuPiZn5AV63fjRXEVw vault-vm";
            })
            (import ../yazi-config.nix { inherit pkgs; })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "vault-vm";

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 30000;
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
                  mem = 1024;
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

                environment.systemPackages = [
                  pkgs.wprs
                  pkgs.xwayland
                  pkgs.keepassxc
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
