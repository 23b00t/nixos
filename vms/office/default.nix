{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/yazi-config.nix
    ../modules/wprs.nix
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
      {
        mountPoint = "/root";
        image = "root.img";
        size = 256;
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
    euro-office-desktopeditors
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
