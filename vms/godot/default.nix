{ lib, pkgs, config, ... }:
let
  vmRegistry = import ../registry.nix;
  gpuPciPaths = vmRegistry.hardware.pci.devicePaths.gpu or [ ];
  mkPciDevice = path: {
    bus = "pci";
    inherit path;
  };
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/yazi-config.nix
    ../modules/ide.nix
    ../modules/zsh.nix
    ../modules/zellij.nix
  ];

  networking.hostName = "godot-vm";
  nixpkgs.config.allowUnfree = true;

  microvm = {
    registerClosure = false;
    hypervisor = "qemu";
    optimize.enable = false;
    qemu.extraArgs = [
      "-display"
      "none"
      "-device"
      "virtio-vga,max_outputs=1"
      "-device"
      "qemu-xhci"
      "-device"
      "virtio-serial-pci"
      "-device"
      "virtio-keyboard-pci"
      "-device"
      "virtio-tablet-pci"
      "-chardev"
      "spicevmc,id=spicechannel0,name=vdagent"
      "-device"
      "virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"
      "-spice"
      "port=5930,addr=127.0.0.1,disable-ticketing=on,image-compression=off,jpeg-wan-compression=never,zlib-glz-wan-compression=never"
    ];
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 20000;
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
    devices = map mkPciDevice gpuPciPaths;
    mem = 16384;
    vcpu = 6;
  };

  services.net-config = {
    enable = true;
    index = 13;
    mac = "00:00:00:00:00:0d";
  };
  services.common-config = {
    enable = true;
  };
  services.ide = {
    enable = true;
    githubAgent.enable = true;
  };
  services.zellij-env = {
    enable = true;
    tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./tabs.kdl;
    };
  };
  services.zsh-env = {
    enable = true;
  };

  services.qemuGuest.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = lib.mkForce false;

  boot.kernelParams = [
    "vfio-pci.disable_idle_d3=1"
    "nvidia-drm.modeset=1"
  ];
  boot.extraModprobeConfig = ''
    options vfio-pci disable_idle_d3=1
    options nvidia-drm modeset=1 fbdev=1
  '';

  boot.blacklistedKernelModules = [ "nouveau" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;

    package = config.boot.kernelPackages.nvidiaPackages.beta;
    prime.offload.enable = false;
    prime.sync.enable = false;
    nvidiaSettings = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
  };

  services.getty.autologinUser = "user";

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  services.spice-vdagentd.enable = true;

  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "${pkgs.hyprland}/bin/start-hyprland";
        user = "user";
      };
      default_session = initial_session;
    };
  };

  environment.etc."hyprland.conf".source = ./hypr.conf;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    icu
    stdenv.cc.cc
    zlib
    icu
    expat
    openssl
    curl
    pulseaudio
    alsa-lib
    dbus
    mesa
    libglvnd
    vulkan-loader
    vulkan-headers
    libvorbis
    libogg
    libopus
    libpng
    libjpeg
    fontconfig
    freetype
    libuuid
    libxcb
    libx11
    libxext
    libxrandr
    libxcursor
    libxi
    libxtst
    libxinerama
    libxscrnsaver
    glib
    gtk3
  ];

  environment.systemPackages = with pkgs; [
    xdg-utils
    kitty
    godot
    wl-clipboard
    firefox
  ];

  systemd.tmpfiles.rules = [
    "L+ /home/user/.config/hypr/hyprland.conf - - - - /etc/hyprland.conf"
  ];

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  system.stateVersion = "26.05";
}
