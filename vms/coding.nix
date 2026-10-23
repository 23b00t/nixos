{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # termusic with the mpv backend and a larger pulse buffer (from the former
  # music VM)
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
{
  imports = [ (inputs.nox.lib.vms + "/modules/persistent-store-overlay.nix") ];

  microvm = {
    # Own closure valid in the Nix DB, so builds never delete it from the
    # persistent store overlay (see vms/builder, 2026-10-06)
    registerClosure = true;
    volumes = lib.mkAfter [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 20000;
      }
    ];
  };

  services = {
    persistentStoreOverlay.enable = true;

    common-config.browser = "firefox.desktop";

    zsh-env = {
      extraAliases = {
        dc = "docker compose";
        cmd = "eval $(fzf < ~/cmds)";
        pcmd = "cmd=$(fzf < ~/cmds); vared -p '> ' -c cmd; eval '$cmd'";
      };
      extraShellInit = ''
        # Countdown shell function
        countdown() {
          termdown "$1" -c 10 && paplay --volume=43000 ~/Music/airhorn.wav
        }
        [ -f "$HOME/paste_functions.zsh" ] && source "$HOME/paste_functions.zsh"
        export PATH="$HOME/.cargo/bin:$PATH"
      '';
    };

    zellij-env.tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./coding/tabs.kdl;
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      8080
    ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  environment.systemPackages = with pkgs; [
    termusic-mpv
    mpv
    yt-dlp

    ddate
    cowsay

    devenv

    ruby

    pulseaudio
    termdown

    helix
    lazysql
    lazydocker
    scooter
    ec
    delta

    lua-language-server
    selene
    lua
    marksman

    rustup
    pkg-config
    openssl.dev
    # rustfmt
    # targets.wasm32-wasip1.latest.rust-std
  ];

  virtualisation = {
    docker = {
      enable = true;
      extraOptions = "--experimental";
      extraPackages = [ pkgs.docker-buildx ];
    };
    podman = {
      enable = true;
      dockerCompat = false;
    };
  };

  # termusic from the former music VM (v3: music goes into coding)
  environment.etc."mpv/mpv.conf".text = ''
    ao=pulse
    pulse-buffer=2000
  '';
  # termusic config from the music VM (backend mpv; the default `rusty` finds
  # no ALSA device in the VM). Copied only if missing: termusic writes to it
  systemd.tmpfiles.rules = [
    "d /home/user/.config/termusic 0755 user users -"
    "C /home/user/.config/termusic/server.toml 0644 user users - ${./coding/termusic/server.toml}"
    "C /home/user/.config/termusic/tui.toml 0644 user users - ${./coding/termusic/tui.toml}"
  ];
}
