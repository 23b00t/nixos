{ pkgs, ... }:
{
  imports = [
    ../modules/common-config.nix
    ../modules/net-config.nix
    ../modules/wprs.nix
  ];

  networking.hostName = "wine-vm";
  nixpkgs.config.allowUnfree = true;

  services.net-config = {
    enable = true;
    index = 7;
    mac = "00:00:00:00:00:07";
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
    mem = 4048;
    vcpu = 4;
  };

  environment.systemPackages = [
    pkgs.protonup-rs
    pkgs.umu-launcher
  ];

  system.stateVersion = "26.05";
}
