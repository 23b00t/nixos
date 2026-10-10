{ pkgs, inputs, ... }:
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
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/ide.nix
    ../modules/zsh.nix
    ../modules/zellij.nix
    ../modules/persistent-store-overlay.nix
    ../modules/wprs.nix
    ../modules/yazi-config.nix
  ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "coding-vm";

  microvm = {
    # Own closure valid in the Nix DB, so builds never delete it from the
    # persistent store overlay (see vms/builder, 2026-10-06)
    registerClosure = true;
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 70000;
      }
      {
        mountPoint = "/var";
        image = "var.img";
        size = 20000;
      }
    ];
    # Boots with 4096 MB, the RAM balancer grows it up to 8192 MB
    mem = 8192;
    balloon = true;
    initialBalloonMem = 4096;
    vcpu = 4;
  };

  services = {
    persistentStoreOverlay.enable = true;

    net-config = {
      enable = true;
      index = 6;
      mac = "00:00:00:00:00:06";
    };

    common-config.enable = true;

    ide = {
      enable = true;
      githubAgent.enable = true;
    };

    zsh-env = {
      enable = true;
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
        export EDITOR=hx
        export PATH="$HOME/.cargo/bin:$PATH"
      '';
    };

    zellij-env = {
      enable = true;
      tabsKdlFile = builtins.path {
        name = "tabs.kdl";
        path = ./tabs.kdl;
      };
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

    postman
    dbeaver-bin
    devenv
    firefox

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

  # dom0's pulse over vchan (vms/modules/vchan-relay.nix), no `ssh -R 4713`
  environment.variables = {
    PULSE_SERVER = "unix:/tmp/wprs-pulse";
  };

  # termusic from the former music VM (v3: music goes into coding)
  environment.etc."mpv/mpv.conf".text = ''
    ao=pulse
    pulse-buffer=2000
  '';

  system.stateVersion = "26.05";
}
