{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/yazi-config.nix
    ../modules/wprs.nix
  ];

  networking.hostName = "vault-vm";

  services.net-config = {
    enable = true;
    index = 10;
    mac = "00:00:00:00:00:0a";
  };
  services.common-config = {
    enable = true;
  };
  microvm = {
    
    hypervisor = "cloud-hypervisor";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 30000;
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
    mem = 1024;
  };

  environment.systemPackages = [
    pkgs.keepassxc
  ];

  system.stateVersion = "26.05";
}
