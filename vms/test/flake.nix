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
      index = 3;
      mac = "00:00:00:00:00:03";
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
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2091GSIL+SlR1BsWswg+6DZzrL+enxmXo74d/OSUwv test-vm";
            })
            ../modules/ide.nix
            ../modules/zsh.nix
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "test-vm";

                microvm = {
                  registerClosure = false;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  # hypervisor = "qemu";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 8000;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 20000;
                    }
                    {
                      image = "nix-db.img";
                      mountPoint = "/persist/nix-db-backup";
                      size = 4096;
                    }
                  ];
                  shares = [
                    {
                      proto = "virtiofs";
                      tag = "ro-store";
                      source = "/nix/store";
                      mountPoint = "/nix/.ro-store";
                    }
                    # {
                    #   proto = "virtiofs";
                    #   tag = "nix-db";
                    #   source = "/nix/var/nix/db";
                    #   mountPoint = "/nix/var/nix/db";
                    # }
                  ];
                  mem = 8192;
                  vcpu = 4;
                };

                programs.direnv = {
                  enable = true;
                  nix-direnv.enable = true;
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    devenv
                  ]
                  ++ defaultPkgs;

                services.ide = {
                  enable = true;
                };

                services.zsh-env = {
                  enable = true;
                  extraShellInit = ''
                    eval "$(devenv hook zsh)"
                  '';
                };

                system.stateVersion = "26.05";

                nix = {
                  settings = {
                    substituters = [
                      "https://cache.nixos.org"
                      "https://microvm.cachix.org"
                    ];
                    trusted-public-keys = [
                      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                      "microvm.cachix.org-1:oXnBs9THCoQI4PiXLm2ODWyptDIrQ2NYjmJfUfpGqMI="
                    ];
                    trusted-users = [
                      "root"
                      "user"
                    ];
                    extra-experimental-features = [
                      "nix-command"
                      "flakes"
                    ];
                  };
                };
                # systemd units for Nix DB backup/restore
                systemd.services.nix-db-backup = {
                  description = "Backup Nix DB before shutdown";
                  wantedBy = [ "shutdown.target" ];
                  before = [ "shutdown.target" ];
                  serviceConfig = {
                    Type = "oneshot";
                    ExecStart = "${pkgs.rsync}/bin/rsync -a --delete /nix/var/nix/db/ /persist/nix-db-backup/";
                  };
                };
                systemd.services.nix-db-restore = {
                  description = "Restore Nix DB at boot";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "local-fs.target" ];
                  serviceConfig = {
                    Type = "oneshot";
                    ExecStart = "${pkgs.bash}/bin/bash -c 'if [ -d /persist/nix-db-backup ] && [ \"$(ls -A /persist/nix-db-backup)\" ]; then exec ${pkgs.rsync}/bin/rsync -a /persist/nix-db-backup/ /nix/var/nix/db/; fi'";
                  };
                };
              }
            )
          ];
        };
      };
    };
}
