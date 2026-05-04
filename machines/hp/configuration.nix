{
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix # Auto-generated hardware config

    # GPU Configuration (choose one):
    inputs.nixos-hardware.nixosModules.common-gpu-amd # AMD

    # CPU Configuration (choose one):
    inputs.nixos-hardware.nixosModules.common-cpu-amd # AMD CPUs
  ];

  # Keyboard layout
  console.keyMap = "us";
  services.xserver.xkb.layout = "us,de";
  services.xserver.xkb.variant = "intl";
  services.xserver.xkb.options = "grp:alt_shift_toggle";

  # TODO: Would need adoption to other hardware
  # services.usbguard = {
  #   enable = true;
  #   rules = ''
  #     allow id 05e3:0610 name "USB2.1 Hub" with-interface { 09:00:01 09:00:02 }
  #     allow id 1a40:0801 name "USB 2.0 Hub" with-interface 09:00:00
  #     allow id 05e3:0620 name "USB3.2 Hub" with-interface 09:00:00
  #
  #     allow id 093a:2533 name "SHARKFORCE OpticalMouse" with-interface { 03:01:02 03:00:01 }
  #     allow id 1209:2303 serial "CDatreus" name "Atreus" with-interface { 02:02:00 0a:00:00 03:01:01 03:00:00 03:00:00 }
  #
  #     allow id 2b7e:c906 serial "200901010001" name "FHD WebCam" with-interface { 0e:01:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:01:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 fe:01:01 }
  #     allow id 8087:0033 with-interface { e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 }
  #   '';
  # };
  # TODO: Fill in registry.nix
  # services.udev.extraRules = ''
  #   # KVM Group Access for USB Devices for Webcam pass through to MicroVM
  #   SUBSYSTEM=="usb", ATTR{idVendor}=="0408", ATTR{idProduct}=="5365", GROUP="kvm"
  # '';

  networking.hostName = lib.mkForce "hp";
}
