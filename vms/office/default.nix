{ pkgs, inputs, ... }:
{
  imports = [
    (inputs.nox.lib.vms + "/modules/net-config.nix")
    (inputs.nox.lib.vms + "/modules/common-config.nix")
    (inputs.nox.lib.vms + "/modules/yazi-config.nix")
  ];

  nixpkgs.config.allowUnfree = true;
  networking.hostName = "office-vm";

  services.net-config = {
    enable = true;
    index = 9;
    mac = "00:00:00:00:00:09";
  };

  services.common-config = {
    enable = true;
  };

  microvm = {
    
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 20000;
      }
    ];
    # Boots with 2048 MB, the RAM balancer grows it up to 6144 MB
    mem = 6144;
    balloon = true;
    initialBalloonMem = 2048;
    vcpu = 4;
  };

  # Printing: `vm-print <printer-ip> <file>` sends the document to sys-print
  # (C2, vms/sys-print); no CUPS and no network here

  environment.systemPackages = with pkgs; [
    libreoffice
    gimp
    inkscape
    vlc
    pinta
    pdfarranger
    adwaita-icon-theme
    dconf
  ];

  system.stateVersion = "26.05";
}
