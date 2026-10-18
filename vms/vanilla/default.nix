# vanilla: only what common-config brings, no packages of its own in the repo.
# Software comes in imperatively (`nix profile install nixpkgs#…`) and stays
# in the persistent store overlay across reboots; GUI apps over wprs.
{ ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/persistent-store-overlay.nix
  ];

  networking.hostName = "vanilla-vm";

  microvm = {
    # Own closure valid in the Nix DB, so a GC in the overlay never deletes it
    # (as in coding/builder)
    registerClosure = true;
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 20000;
      }
    ];
    # Boots with 2048 MB, the RAM balancer grows it up to 4096 MB
    mem = 4096;
    balloon = true;
    initialBalloonMem = 2048;
    vcpu = 1;
  };

  services = {
    persistentStoreOverlay.enable = true;

    net-config = {
      enable = true;
      index = 29;
      mac = "00:00:00:00:00:1d";
    };

    common-config.enable = true;
  };

  system.stateVersion = "26.05";
}
