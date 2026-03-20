{
  pkgs,
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
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    plymouth.enable = true;
    initrd = {
      systemd.enable = true;
      kernelModules = [
        "nvme"
        "sd_mod"
        "dm-crypt"
        "dm-mod"
        # GPU passthrough
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
      ];
      services.lvm.enable = true;
      luks.devices."luks-90b3e0c2-5fdb-48ac-b4b9-3ee6f5cb533e".device =
        "/dev/disk/by-uuid/90b3e0c2-5fdb-48ac-b4b9-3ee6f5cb533e";
    };
    kernelPackages = pkgs.linuxPackages_zen;

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

    # (Optional) Host-Display nur über iGPU: sicherstellen, dass i915 geladen wird
    # kernelModules = [ "i915" ];
    kernel.sysctl = {
      # Disable bridge netfilter for Whonix Gateway compatibility
      "net.bridge.bridge-nf-call-ip6tables" = 0;
      "net.bridge.bridge-nf-call-iptables" = 0;
      "net.bridge.bridge-nf-call-arptables" = 0;

      # see: https://github.com/wayland-transpositor/wprs?tab=readme-ov-file#system-tuning
      # and: https://wiki.archlinux.org/title/Sysctl#Increase_the_memory_dedicated_to_the_network_interfaces
      # Increase maximum and default socket buffer sizes for better network throughput
      "net.core.rmem_max" = 33554432; # Max receive buffer: 32 MB
      "net.core.wmem_max" = 33554432; # Max send buffer: 32 MB
      "net.core.rmem_default" = 2097152; # Default receive buffer: 2 MB
      "net.core.wmem_default" = 2097152; # Default send buffer: 2 MB
      "net.core.optmem_max" = 65536; # Max ancillary buffer: 64 KB

      # TCP buffer settings: min, default, and max values for receive/send buffers
      "net.ipv4.tcp_rmem" = "4096 1048576 2097152"; # TCP receive buffer sizes
      "net.ipv4.tcp_wmem" = "4096 65536 16777216"; # TCP send buffer sizes

      # UDP minimum buffer sizes for receive and send
      "net.ipv4.udp_rmem_min" = 16384; # Min UDP receive buffer: 16 KB
      "net.ipv4.udp_wmem_min" = 16384; # Min UDP send buffer: 16 KB

      # Connection tracking: increase max tracked connections for high-load environments
      "net.netfilter.nf_conntrack_max" = 262144; # Max number of tracked connections

      # TCP connection handling
      "net.ipv4.tcp_fin_timeout" = 30; # Time to wait for FIN-WAIT-2 state (seconds)
      "net.ipv4.tcp_keepalive_time" = 600; # Interval before sending keepalive probes (seconds)
    };
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
