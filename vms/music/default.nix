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

  environment.etc."mpv/mpv.conf".text = ''
    ao=pulse
    pulse-buffer=2000
  '';

  environment.systemPackages =
    let
      termusic-mpv = pkgs.termusic.overrideAttrs (old: {
        cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features=mpv" ];
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          pkgs.pkg-config
          pkgs.python3
        ];
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.mpv ];
        postPatch = (old.postPatch or "") + ''
python3 <<'PY'
from pathlib import Path

path = Path("playback/src/backends/mpv/mod.rs")
old = """        mpv.set_property("vo", "null")
            .expect("Couldn't set vo=null in libmpv");
"""
new = """        mpv.set_property("vo", "null")
            .expect("Couldn't set vo=null in libmpv");
        mpv.set_property("pulse-buffer", 2000i64)
            .expect("Couldn't set pulse-buffer property");
"""

text = path.read_text()
if old not in text:
    raise SystemExit("expected mpv init block not found")
path.write_text(text.replace(old, new, 1))
PY
        '';
      });
    in
    with pkgs;
    [
      termusic-mpv
      mpv
      pulseaudio
      yt-dlp
    ];

  system.stateVersion = "26.05";
}
