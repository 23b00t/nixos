{ pkgs, ... }:
let
  vmRegistry = import ../registry.nix;
  defaultUsbDevices = vmRegistry.hardware.usb.defaultForOwner "sys-usb";
  mkUsbDevice = device: {
    bus = "usb";
    path = device.microvmUsbPath;
  };
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/yazi-config.nix
    ../modules/wprs.nix
  ];

  networking.hostName = "sys-usb-vm";

  services.net-config = {
    enable = true;
    index = 23;
    mac = "00:00:00:00:00:fc";
  };

  services.common-config = {
    enable = true;
    withDefaultPkgs = false;
  };

  boot.kernelModules = [
    "btusb"
    "btintel"
  ];

  microvm = {
    hypervisor = "qemu";
    optimize.enable = false;
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
    devices = map mkUsbDevice defaultUsbDevices;
    mem = 1024;
    vcpu = 1;
  };

  environment.systemPackages = with pkgs; [
    blueman
    bluez
    bluez-tools
    dbus
    dosfstools
    exfatprogs
    exfat
    ntfs3g
    parted
    udisks2
    usbutils
    util-linux
  ];

  services.dbus.enable = true;
  services.udisks2.enable = true;
  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          subject.isInGroup("wheel") &&
          action.id.indexOf("org.freedesktop.udisks2.") == 0
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };
  programs.dconf.enable = true;

  services.blueman.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
        Enable = "Source,Sink,Media,Socket";
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };
  services.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
    extraConfig = ''
      load-module module-switch-on-connect
    '';
  };

  system.stateVersion = "26.05";
}
