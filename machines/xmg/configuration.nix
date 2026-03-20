{
  lib,
  inputs,
  ...
}:
let
  devices = [
    "10de:2d19" # NVIDIA RTX 5060 Max-Q (VGA)
    "10de:22eb" # NVIDIA RTX 5060 Audio
  ];
in
{
  boot = {
    initrd = {
      kernelModules = lib.mkAfter [
        # GPU passthrough
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
      ];
      luks.devices."luks-90b3e0c2-5fdb-48ac-b4b9-3ee6f5cb533e".device =
        "/dev/disk/by-uuid/90b3e0c2-5fdb-48ac-b4b9-3ee6f5cb533e";
    };

    # Enable IOMMU for device passthrough to MicroVMs
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
      "vfio-pci.ids=${lib.concatStringsSep "," devices}"
    ];
    # NVIDIA-Treiber blacklisten, damit der Host die dGPU nicht bindet
    extraModprobeConfig = ''
      softdep nvidia pre: vfio-pci
      softdep drm pre: vfio-pci
      softdep nouveau pre: vfio-pci
    '';
    blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "i2c_nvidia_gpu"
    ];
  };

  imports = [
    ./hardware-configuration.nix # Auto-generated hardware config

    # CPU Configuration (choose one):
    inputs.nixos-hardware.nixosModules.common-cpu-intel # Intel CPUs
  ];

  # Keyboard layout
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "intl";
  services.xserver.xkb.options = "grp:alt_shift_toggle";

  services.udev.extraRules = ''
    # KVM Group Access for USB Devices for Webcam pass through to MicroVM
    SUBSYSTEM=="usb", ATTR{idVendor}=="2b7e", ATTR{idProduct}=="c906", GROUP="kvm"
    # Intel AX211 Bluetooth
    SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", GROUP="kvm", MODE="0660"
  '';

  # Steam VM CPU pinning
  systemd.services."microvm@steam".serviceConfig.CPUAffinity = "0 1 2 3 4 5 6 7 8 9";

  # Optional
  # networking.hostName = lib.mkForce "xmg";
  hydenix.hostname = lib.mkForce "xmg";
  networking.hostName = lib.mkForce "xmg";
}
