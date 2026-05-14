{ lib, pkgs, config, ... }:
let
  vmRegistry = import ../registry.nix;
  usb = vmRegistry.hardware.usb.byName;
  allowedUsbDevices = vmRegistry.hardware.usb.allowedForOwner "steam";
  bluetoothUsbDevice = usb."bluetooth-ax211";
  steamUsbDevices = builtins.filter (
    device: builtins.elem device.name [
      "mouse-main"
      "keyboard-atreus"
      bluetoothUsbDevice.name
    ]
  ) allowedUsbDevices;
  gpuPciPaths = vmRegistry.hardware.pci.devicePaths.gpu or [ ];
  mkUsbDevice = device: {
    bus = "usb";
    path = device.microvmUsbPath;
  };
  mkPciDevice = path: {
    bus = "pci";
    inherit path;
  };
in
{
  imports = [
    ../modules/net-config.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      inherit (final.lixPackageSets.latest)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        colmena
        ;
    })
  ];

  nix.package = pkgs.lixPackageSets.latest.lix;

  nixpkgs.config.allowUnfree = true;
  networking.hostName = "steam-vm";
  services.net-config = {
    enable = true;
    index = 12;
    mac = "00:00:00:00:00:0c";
  };

  microvm = {
    hypervisor = "qemu";
    optimize.enable = false;
    qemu.extraArgs = [
      "-smp"
      "10,sockets=1,cores=10,threads=1"
      "-mem-prealloc"
    ];
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 220000;
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
    devices = (map mkPciDevice gpuPciPaths) ++ map mkUsbDevice steamUsbDevices;
    mem = 16384;
    vcpu = 10;
  };

  services.qemuGuest.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = lib.mkForce false;

  boot.kernelParams = [
    "vfio-pci.disable_idle_d3=1"
    "nvidia-drm.modeset=1"
    "pci=realloc=on"
    "pci=assign-busses"
  ];
  boot.extraModprobeConfig = ''
    options vfio-pci disable_idle_d3=1
    options nvidia-drm modeset=1 fbdev=1
  '';

  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.kernelPackages = pkgs.linuxPackages_zen;

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

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
  };

  programs.gamemode.enable = true;

  services.getty.autologinUser = "user";

  services.seatd = {
    enable = true;
    group = "seat";
  };

  environment.loginShellInit = ''
    if [[ "$(tty)" = "/dev/tty1" ]]; then
      exec "$HOME/gs.sh"
    fi
  '';

  environment.etc."gs.sh" = {
    mode = "0755";
    text = ''
      #!/usr/bin/env bash
      set -xeuo pipefail

      MAXMODE=$(head -1 /sys/class/drm/card0-HDMI-A-1/modes)
      if [[ "$MAXMODE" == "1920x1080" ]]; then
        DEVICE_TYPE="monitor"
      else
        DEVICE_TYPE="tv"
      fi

      if [[ "$DEVICE_TYPE" == "monitor" ]]; then
        gamescopeArgs=(
          --adaptive-sync
          --mangoapp
          --rt
          --steam
          --backend drm
          --immediate-flips
        )
      else
        gamescopeArgs=(
          --adaptive-sync
          --hdr-enabled
          --mangoapp
          --rt
          --steam
          --backend drm
          -W 3840 -H 2160 -w 3840 -h 2160
          --immediate-flips
        )
      fi
      steamArgs=(
        -steamdeck
        -steamos3
      )

      export __GLX_VENDOR_LIBRARY_NAME=nvidia

      exec dbus-run-session -- gamescope "''${gamescopeArgs[@]}" -- steam "''${steamArgs[@]}"
    '';
  };

  systemd.tmpfiles.rules = [
    "L+ /home/user/gs.sh - - - - /etc/gs.sh"
    "L+ /home/user/.ssh/config - - - - /etc/ssh_config"
  ];

  environment.systemPackages = with pkgs; [
    mangohud
    pciutils
    dbus
    vim
    btop
    protonup-rs
  ];
  services.dbus.enable = true;

  networking.networkmanager.enable = true;
  networking.networkmanager.settings = {
    main.no-auto-default = "*";
  };

  services.upower.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  users.groups.users = { };
  users.groups.seat = { };

  users.users.user = {
    isNormalUser = true;
    group = "users";
    extraGroups = [
      "wheel"
      "seat"
      "video"
      "render"
      "input"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/v5mOcbtZ/shL0s5Y2xJYkfEdkPMsznhEC3X7cGgmL steam-vm"
    ];
  };

  environment.etc."ssh_config".text = ''
    Host *
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
  '';

  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        AutoEnable = true;
        FastConnectable = true;
      };
    };
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  environment.sessionVariables = {
    TERM = "xterm-256color";
  };

  system.stateVersion = "26.05";
}
