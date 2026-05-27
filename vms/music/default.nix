{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
  ];

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

  services.timesyncd.enable = false;

  environment.variables = {
    PULSE_SERVER = "tcp:localhost:4713";
  };

  environment.systemPackages =
    let
      termusic-mpv = pkgs.termusic.overrideAttrs (old: {
        cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features=mpv" ];
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.mpv ];
      });
    in
    with pkgs;
    [
      termusic-mpv
      yt-dlp
    ];

  system.stateVersion = "26.05";
}
