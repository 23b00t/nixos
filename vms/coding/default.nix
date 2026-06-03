{ pkgs, inputs, ... }:
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
    registerClosure = false;
    
    hypervisor = "cloud-hypervisor";
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
    mem = 8192;
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

    rustup
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

  environment.variables = {
    PULSE_SERVER = "tcp:localhost:4713";
  };

  system.stateVersion = "26.05";
}
