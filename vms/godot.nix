{
  lib,
  pkgs,
  config,
  vmRegistry,

  ...
}:
let
  gpuPciPaths = vmRegistry.hardware.pci.devicePaths.gpu or [ ];
  mkPciDevice = path: {
    bus = "pci";
    inherit path;
  };
in
{
  nixpkgs.config.allowUnfree = true;

  # Not migrated yet (enable = false): GPU passthrough as an Xen HVM like
  # steam comes with the godot migration
  microvm = {
    registerClosure = false;
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    devices = map mkPciDevice gpuPciPaths;
  };

  services.common-config.browser = "firefox.desktop";
  services.zellij-env.tabsKdlFile = builtins.path {
    name = "tabs.kdl";
    path = ./godot/tabs.kdl;
  };

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

    package = config.boot.kernelPackages.nvidiaPackages.stable;
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

  environment.etc."hyprland.conf".source = ./godot/hypr.conf;

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

}
