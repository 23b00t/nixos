{ lib, pkgs, ... }:
{
  services.zsh-env.extraShellInit = ''
    start() {
      sudo docker compose start
    }
    stop() {
      sudo docker compose stop
    }
  '';

  services.zellij-env.tabsKdlFile = builtins.path {
    name = "tabs.kdl";
    path = ./ruby/tabs.kdl;
  };

  microvm.volumes = lib.mkAfter [
    {
      mountPoint = "/var";
      image = "var.img";
      size = 10000;
    }
  ];

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
}
