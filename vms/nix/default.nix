{ pkgs, inputs, ... }:
{
  imports = [
    (inputs.nox.lib.vms + "/modules/net-config.nix")
    (inputs.nox.lib.vms + "/modules/common-config.nix")
    (inputs.nox.lib.vms + "/modules/ide.nix")
    (inputs.nox.lib.vms + "/modules/zsh.nix")
    (inputs.nox.lib.vms + "/modules/zellij.nix")
    (inputs.nox.lib.vms + "/modules/yazi-config.nix")
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
    
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 10000;
      }
    ];
    mem = 8192;
    vcpu = 2;
  };

  environment.systemPackages = with pkgs; [
    # Unfree, the user's own (no longer from NoX ide.nix)
    claude-code
    nil
    # nixd
    nixdoc
    nixfmt
    deadnix
  ];

  system.stateVersion = "26.05";
}
