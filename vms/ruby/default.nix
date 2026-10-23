{ pkgs, lib, inputs, ... }:
{
  imports = [
    (inputs.nox.lib.vms + "/modules/net-config.nix")
    (inputs.nox.lib.vms + "/modules/yazi-config.nix")
    (inputs.nox.lib.vms + "/modules/ide.nix")
    (inputs.nox.lib.vms + "/modules/zsh.nix")
    (inputs.nox.lib.vms + "/modules/zellij.nix")
    (inputs.nox.lib.vms + "/modules/common-config.nix")
  ];

  networking.hostName = "ruby-vm";

  services.net-config = {
    enable = true;
    index = 16;
    mac = "00:00:00:00:00:10";
  };
  services.common-config = {
    enable = true;
  };
  services.ide = {
    enable = true;
    githubAgent.enable = true;
  };
  services.zsh-env = {
    enable = true;
    extraShellInit = ''
      start() {
        sudo docker compose start
      }
      stop() {
        sudo docker compose stop
      }
    '';
  };

  services.zellij-env = {
    enable = true;
    tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./tabs.kdl;
    };
  };

  microvm = {
    
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 25000;
      }
      {
        mountPoint = "/var";
        image = "var.img";
        size = 10000;
      }
    ];

    # Boots with 4096 MB, the RAM balancer grows it up to 12288 MB
    mem = 12288;
    balloon = true;
    initialBalloonMem = 4096;
    vcpu = 2;
  };

  environment.systemPackages = with pkgs; [
    libyaml
    gcc
    cmake
    pkg-config
    zlib
    yarn
    postgresql
    sqlite
    bundler
    nodejs
    imagemagick
    libffi
    libxml2
    libxslt
    openssl
    wkhtmltopdf
    watchman
    rbenv
  ];

  programs.direnv.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      3000
    ];
  };

  virtualisation.docker = {
    enable = true;
    extraOptions = "--experimental";
    extraPackages = [ pkgs.docker-buildx ];
    enableOnBoot = true;
    daemon.settings = {
      dns = [
        "8.8.8.8"
        "1.1.1.1"
      ];
    };
  };

  system.stateVersion = "26.05";
}
