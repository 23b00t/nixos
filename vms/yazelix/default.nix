{ pkgs, inputs, ... }:
let
  yazelixPkg = inputs.yazelix.packages.${pkgs.stdenv.hostPlatform.system}.yazelix;
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/zsh.nix
    ../modules/wprs.nix
  ];

  networking.hostName = "yazelix-vm";

  services.net-config = {
    enable = true;
    index = 25;
    mac = "00:00:00:00:00:19";
  };

  services.zsh-env = {
    enable = true;
  };

  services.common-config.enable = true;

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
    yazelixPkg
  ];

  system.stateVersion = "26.05";
}
