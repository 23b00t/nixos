{
  lib,
  inputs,
  vmRegistry,
  ...
}:
let
  # e.g. lspci -n -s 00:14.3 (for WiFi)
  devices = [
    "10de:2d19" # NVIDIA RTX 5060 Max-Q (VGA)
    "10de:22eb" # NVIDIA RTX 5060 Audio
    "8086:7a70" # WiFi
    "10ec:8125" # Ethernet
  ];

  usb = vmRegistry.hardware.usb.byName;

  mkUsbAllowRule = device: extraAssignments: let
    assignments =
      [ ''ATTR{authorized}="1"'' ]
      ++ extraAssignments;
  in
    ''ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", KERNEL=="${device.topologyPath}", ${lib.concatStringsSep ", " assignments}, GOTO="xmg_usb_policy_end"'';

  mkUsbDenyRule = topologyPath:
    ''ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", KERNEL=="${topologyPath}", ATTR{authorized}="0", GOTO="xmg_usb_policy_end"'';
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
      "uvcvideo"
      "btusb"
      "bluetooth"
      "btintel"
      "btrtl"
      "btmtk"
      "btbcm"
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
    # Keep root hubs managed by the host.
    ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", KERNEL=="usb*", GOTO="xmg_usb_policy_end"

    # Explicit host-allowed USB plumbing and input devices.
    ${mkUsbAllowRule usb."keyboard-hub" [ ]}
    ${mkUsbAllowRule usb."keyboard-atreus" [ ]}
    ${mkUsbAllowRule usb."mouse-hub" [ ]}
    ${mkUsbAllowRule usb."mouse-main" [ ]}
    ${mkUsbAllowRule usb."monitor-hub-main" [ ]}
    ${mkUsbAllowRule usb."ite-8291" [ ]}

    # VM-reserved devices stay authorized for passthrough, but host drivers are blacklisted.
    ${mkUsbAllowRule usb."webcam-main" [ ''GROUP="kvm"'' ''MODE="0660"'' ]}
    ${mkUsbAllowRule usb."bluetooth-ax211" [ ''GROUP="kvm"'' ''MODE="0660"'' ]}

    # Monitor hub descendants are untrusted by default.
    ${mkUsbDenyRule "2-1.*"}

    # Default deny for every other external USB device.
    ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{authorized}="0"

    LABEL="xmg_usb_policy_end"
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

  # Optional
  # networking.hostName = lib.mkForce "xmg";
  networking.hostName = lib.mkForce "xmg";
}
