{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
  ];

  networking.hostName = "builder-vm";

  services.net-config = {
    enable = true;
    index = 25;
    mac = "00:00:00:00:00:19";
  };

  services.common-config = {
    enable = true;
    withDefaultPkgs = false;
    vmCopy.enable = false;
  };

  microvm = {
    registerClosure = false;
    hypervisor = "cloud-hypervisor";
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    mem = 32768;
    vcpu = 16;
  };

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://microvm.cachix.org"
        "https://hyprland.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = [
        "nx"
      ];
    };
  };

  system.stateVersion = "26.05";
}
