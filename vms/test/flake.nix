{
  description = "test MicroVM";

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
            (
              { config, pkgs, ... }:
              let
                # INFO: build tertest with mpv support to work with pulse and not enforce alsa
                termusic-mpv = pkgs.termusic.overrideAttrs (old: {
                  cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features=mpv" ];
                  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
                  buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.mpv ];
                });

                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "test-vm";

                microvm = {

                  registerClosure = false;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 4096;
                    }
                    {
                      mountPoint = "/var/log";
                      image = "log.img";
                      size = 512;
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
                };

                # For tertest
                environment.variables = {
                  PULSE_SERVER = "tcp:localhost:4713";
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    # INFO: set in .config/tertest/server.toml:
                    # [player]
                    # backend = "mpv"
                    # [backends.mpv]
                    # audio_device = "pulse"
                    termusic-mpv
                    # pulseaudio
                    # mpv
                    yt-dlp
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
