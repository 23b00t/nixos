{ pkgs, inputs, ... }:
{
  imports = [
    (inputs.nox.lib.vms + "/modules/net-config.nix")
    (inputs.nox.lib.vms + "/modules/ide.nix")
    (inputs.nox.lib.vms + "/modules/zsh.nix")
    (inputs.nox.lib.vms + "/modules/persistent-store-overlay.nix")
    (inputs.nox.lib.vms + "/modules/common-config.nix")
  ];

  nixpkgs.config.allowUnfree = true;
  networking.hostName = "test-vm";

  services.net-config = {
    enable = true;
    index = 3;
    mac = "00:00:00:00:00:03";
  };
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
        size = 8000;
      }
    ];
    mem = 8192;
    vcpu = 4;
  };

  environment.systemPackages = with pkgs; [
    devenv
  ];

  services.ide.enable = true;
  services.zsh-env.enable = true;
  services.persistentStoreOverlay.enable = true;

  system.stateVersion = "26.05";
}
