{ pkgs, inputs, ... }:
{
  imports = [
    (inputs.nox.lib.vms + "/modules/net-config.nix")
    (inputs.nox.lib.vms + "/modules/common-config.nix")
    (inputs.nox.lib.vms + "/modules/ide.nix")
    (inputs.nox.lib.vms + "/modules/zsh.nix")
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
    
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 12000;
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
