{
  description = "music MicroVM";

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
        default = self.packages.${system}.music;
        music = self.nixosConfigurations.music.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        music = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/common-config.nix
            (
              { config, pkgs, ... }:
              let
                # INFO: build termusic with mpv support to work with pulse and not enforce alsa
                termusic-mpv = pkgs.termusic.overrideAttrs (old: {
                  cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features=mpv" ];
                  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
                  buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.mpv ];
                });
              in
              {
                services.net-config = {
                  enable = true;
                  index = 4;
                  mac = "00:00:00:00:00:04";
                };
                services.common-config = {
                  enable = true;
                  
                };
                networking.hostName = "music-vm";

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
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
                  ];
                };

                # Fix shutdown problem with time-sync timeout
                services.timesyncd.enable = false;

                # For termusic
                environment.variables = {
                  PULSE_SERVER = "tcp:localhost:4713";
                };

                environment.systemPackages = with pkgs; [
                  # INFO: set in .config/termusic/server.toml:
                  # [player]
                  # backend = "mpv"
                  # [backends.mpv]
                  # audio_device = "pulse"
                  termusic-mpv
                  # pulseaudio
                  # mpv
                  yt-dlp

                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
