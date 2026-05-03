{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/ide.nix
    ../modules/zsh.nix
  ];

  networking.hostName = "mirage-vm";
  services.net-config = {
    enable = true;
    index = 14;
    mac = "00:00:00:00:00:0e";
  };
  services.ide = {
    enable = true;
    githubAgent.enable = true;
  };
  services.zsh-env.enable = true;
  services.common-config = {
    enable = true;
  };

  microvm = {
    registerClosure = false;
    hypervisor = "cloud-hypervisor";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 12000;
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

    mem = 8192;
    vcpu = 4;
  };

  environment.systemPackages = with pkgs; [
    opam
    mercurial
    darcs
    bubblewrap
    gcc
    gnumake
    pkg-config
    rsync
    pkg-config
  ];

  system.stateVersion = "26.05";
}
