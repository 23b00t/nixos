{
  lib,
  inputs,
  ...
}:
let
  vmRegistry = import ../../vms/registry.nix;

  mkVmReservedUsbRule =
    device:
    let
      udev = device.udev or { };
      group = udev.group or "kvm";
      modePart = lib.optionalString (udev ? mode) '' , MODE="${udev.mode}"'';
      udisksPart = lib.optionalString (udev.udisksIgnore or false)
        '' , ENV{UDISKS_IGNORE}="1", TAG-="uaccess"'';
    in
    ''SUBSYSTEM=="usb", ATTR{idVendor}=="${device.vendorId}", ATTR{idProduct}=="${device.productId}", GROUP="${group}"${modePart}${udisksPart}'';

  vmReservedUsbRules = lib.concatMapStringsSep "\n" mkVmReservedUsbRule vmRegistry.hardware.usb.vmReserved;

  # e.g. lspci -n -s 00:14.3 (for WiFi)
  devices = [
    "10de:2d19" # NVIDIA RTX 5060 Max-Q (VGA)
    "10de:22eb" # NVIDIA RTX 5060 Audio
    "8086:7a70" # WiFi
    "10ec:8125" # Ethernet
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
      "r8169"
      "iwlwifi"
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
    # VM-reserved USB devices are generated from vms/registry.nix
    ${vmReservedUsbRules}
  '';

  services.keyd = {
    enable = true;
    keyboards = {
      internal = {
        # IDs, wie z.B. ["0001:0001"] (Vendor:Product)
        # journalctl -xeu keyd.service | grep -i keyboard
        ids = [ "0001:0001" ];
        settings = {
          main = {
            y = "z";
            z = "y";
            # leftctrl = "esc";
            # esc = "leftctrl";
          };
        };
      };
    };
  };

  # Steam VM CPU pinning
  systemd.services."microvm@steam".serviceConfig.CPUAffinity = "0 1 2 3 4 5 6 7 8 9";

  networking.hostName = lib.mkForce "xmg";
}
