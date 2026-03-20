{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    initrd = {
      systemd.enable = true;
      kernelModules = [
        "nvme"
        "sd_mod"
        "dm-crypt"
        "dm-mod"
      ];
      services.lvm.enable = true;
    };
    kernelPackages = pkgs.linuxPackages_zen;

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

  hydenix.hostname = lib.mkForce "hp";
  networking.hostName = lib.mkForce "hp";
}
