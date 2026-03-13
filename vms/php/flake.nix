{
  description = "php MicroVM";

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
      index = 15;
      mac = "00:00:00:00:00:0f";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.php;
        php = self.nixosConfigurations.php.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        php = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHpfcEv27hamz0HELXGKpLd6M+/m5m/fopZ3A7fonUVw php-vm";
            })
            ../modules/ide.nix
            ../modules/zsh.nix
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };

                devenvConfig = import ./devenv.nix {
                  inherit pkgs;
                  # "Fake"-config für den Import-Kontext von devenv.nix:
                  config = {
                    env = {
                      DEVENV_ROOT = "/home/user/project"; # Pfad in der VM anpassen
                    };
                  };
                };
                envVars = devenvConfig.env or { };
                devPkgs = devenvConfig.packages or [ ];
                scripts = devenvConfig.scripts or { };
                processes = devenvConfig.processes or { };
              in
              {
                networking.hostName = "php-vm";
                services.ide.enable = true;
                services.zsh-env.enable = true;

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 12000;
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
                  vcpu = 2;
                };

                services.ide.enable = true;
                services.zsh-env.enable = true;

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
