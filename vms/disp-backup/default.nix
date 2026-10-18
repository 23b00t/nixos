# disp-backup: disposable for `nox backup` (spec in xen-migration.md "Spec
# Backup"): holds the backup disk (USB/IP from sys-usb), no network, empty
# home on every start (registry `disposable`, machines/xen-dom0.nix). The
# backup role (rpc services, rsync, LUKS) comes with the backup step.
{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
  ];

  networking.hostName = "disp-backup-vm";

  microvm = {
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 20000;
      }
    ];
    mem = 1024;
    vcpu = 2;
  };

  services = {
    net-config = {
      enable = true;
      index = 32;
      mac = "00:00:00:00:00:20";
    };

    common-config = {
      enable = true;
      withDefaultPkgs = false;
    };
  };

  environment.systemPackages = with pkgs; [
    cryptsetup
    rsync
  ];

  system.stateVersion = "26.05";
}
