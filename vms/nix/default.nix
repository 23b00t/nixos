{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/ide.nix
    ../modules/zsh.nix
    ../modules/zellij.nix
    ../modules/yazi-config.nix
  ];

  nixpkgs.config.allowUnfree = true;
  networking.hostName = "nix-vm";

  services.net-config = {
    enable = true;
    index = 24;
    mac = "00:00:00:00:00:18";
  };

  services.common-config.enable = true;

  services.ide = {
    enable = true;
    githubAgent.enable = true;
  };
  services.zsh-env.enable = true;
  services.zellij-env.enable = true;

  microvm = {
    registerClosure = false;
    hypervisor = "cloud-hypervisor";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 10000;
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
    mem = 4096;
    vcpu = 2;
  };

  environment.systemPackages = with pkgs; [
    nil
    nixd
    nixdoc
    nixfmt
  ];

  system.stateVersion = "26.05";
}
