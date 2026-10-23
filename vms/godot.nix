{
  lib,
  pkgs,
  config,

  ...
}:
{
  # Unfree, own store image
  nox.unfree = [
    "nvidia-x11"
    "nvidia-settings"
  ];

  # Not migrated yet (enable = false): the GPU (gpu = true) as an Xen HVM
  # like steam comes with the godot migration
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
  };

  services = {
    common-config.browser = "firefox.desktop";
    zellij-env.tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./godot/tabs.kdl;
    };
    xserver.videoDrivers = [ "nvidia" ];
    getty.autologinUser = "user";
    greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          command = "${pkgs.hyprland}/bin/start-hyprland";
          user = "user";
        };
        default_session = initial_session;
      };
    };
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
    };
    kernelParams = [
      "vfio-pci.disable_idle_d3=1"
      "nvidia-drm.modeset=1"
    ];
    extraModprobeConfig = ''
      options vfio-pci disable_idle_d3=1
      options nvidia-drm modeset=1 fbdev=1
    '';
    blacklistedKernelModules = [ "nouveau" ];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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

  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
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
    };
  };

  environment.etc."hyprland.conf".source = ./godot/hypr.conf;

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

  security.rtkit.enable = true;
}
