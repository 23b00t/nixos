{
  lib,
  inputs,
  ...
}:
{
  imports = [
    # hydenix inputs - Required modules, don't modify unless you know what you're doing
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

  services.udev.extraRules = ''
    # KVM Group Access for USB Devices for Webcam pass through to MicroVM
    SUBSYSTEM=="usb", ATTR{idVendor}=="0408", ATTR{idProduct}=="5365", GROUP="kvm"
  '';

  networking.hostName = lib.mkForce "hp";
}
