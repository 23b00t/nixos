{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/yazi-config.nix
    ../modules/wprs.nix
  ];

  services.net-config = {
    enable = true;
    index = 8;
    mac = "00:00:00:00:00:08";
  };

  services.common-config = {
    enable = true;
  };

  networking.hostName = "kali-vm";

  microvm = {
    registerClosure = false;
    hypervisor = "cloud-hypervisor";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 20000;
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
    vcpu = 6;
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  environment.systemPackages = [
    pkgs.distrobox
  ];

  system.stateVersion = "26.05";
}
