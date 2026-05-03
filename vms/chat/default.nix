{ lib, pkgs, ... }:
let
  vmRegistry = import ../registry.nix;
  defaultUsbDevices = vmRegistry.hardware.usb.defaultForOwner "chat";
  webcamUsbDevice = builtins.head defaultUsbDevices;
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/wprs.nix
    ../modules/yazi-config.nix
  ];

  services.net-config = {
    enable = true;
    index = 2;
    mac = "00:00:00:00:00:02";
  };

  services.common-config = {
    enable = true;
  };

  nixpkgs.config.allowUnfree = true;
  networking.hostName = "chat-vm";

  users.users.user.extraGroups = lib.mkAfter [ "video" ];

  microvm = {
    registerClosure = false;
    hypervisor = "qemu";
    optimize.enable = false;

    qemu.extraArgs = [
      "-nodefaults"
      "-device"
      "usb-ehci,id=ehci"
      "-device"
      "usb-host,bus=ehci.0,${webcamUsbDevice.microvmUsbPath},guest-reset=false,pipeline=false"
    ];

    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 4096;
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
    mem = 8192;
    vcpu = 2;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  services.gnome.gnome-keyring.enable = true;

  environment.systemPackages = with pkgs; [
    vesktop
    telegram-desktop
    slack
    element-desktop
    google-chrome
    chromium

    mesa
    vulkan-loader

    kitty
    v4l-utils
  ];

  system.stateVersion = "26.05";
}
