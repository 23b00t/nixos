{ zen-browser, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/wprs.nix
    ../modules/zen-firefox.nix
    ../modules/yazi-config.nix
  ];

  networking.hostName = "net-vm";

  services.net-config = {
    enable = true;
    index = 5;
    mac = "00:00:00:00:00:05";
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
        size = 10000;
      }
    ];
    # Boots with 3072 MB, the RAM balancer grows it up to 6144 MB
    mem = 6144;
    balloon = true;
    initialBalloonMem = 3072;
    vcpu = 2;
  };

  programs.firefox = {
    enable = true;
    languagePacks = [
      "de"
      "en-US"
    ];
  };

  system.stateVersion = "26.05";
}
