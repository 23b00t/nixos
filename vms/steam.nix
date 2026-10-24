# steam (v4): Xen HVM with the NVIDIA dGPU passed through (gamescope runs on
# its HDMI output, as before under KVM). Keyboard, mouse and the Bluetooth
# adapter come over USB/IP from sys-usb (`vm-usb attach <device> steam`),
# dom0 calls over nox-rpc (vms/modules/vchan-relay.nix), no sshd.
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  # One zero byte: SeaBIOS reads fw_cfg integers as raw little-endian bytes
  optionRomExecOff = pkgs.runCommand "pci-optionrom-exec-0" { } "printf '\\000' > $out";
in
{
  imports = [
    (inputs.nox.lib.vms + "/modules/vchan-relay.nix")
    # GUI and foot over wprs instead of SSH (no common-config here)
    (inputs.nox.lib.vms + "/modules/wprs.nix")
  ];

  # Unfree, own store image
  nox.unfree = [
    "steam"
    "steam-unwrapped"
    "nvidia-x11"
    "nvidia-settings"
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

  # Ctrl+Alt+Del on the keyboard from input-to must not reboot steam
  # (vms/modules/common-config.nix, not imported here)
  systemd.ctrlAltDelUnit = "/dev/null";

  microvm = {
    xen = {
      # PCI passthrough with a PVH dom0 only works for HVM guests
      type = "hvm";
      # P-cores: dom0 (machines/xmg/xen.nix) moves CPUs 0-15 into this
      # pool while steam runs (before: cpus = "0-9", shared with Pool-0)
      pool = "steam";
      # The NVIDIA driver writes config space registers pciback filters
      # otherwise (common for GPU passthrough on Xen)
      # SeaBIOS ran the NVIDIA VGA option ROM from the passed-through card and
      # hung there (one vCPU at 100 %, the others never started, last line in
      # `xl dmesg`: "Running option rom at c000:0003", 2026-10-14). The kernel
      # boots directly and the driver sets the card up itself, so SeaBIOS
      # runs no PCI option ROMs (fw_cfg etc/pci-optionrom-exec = 0, a binary
      # integer)
      # on_reboot: xl restarts the domain itself on a guest reboot, so a
      # poweroff from inside Steam ends the unit for good (the host sets
      # Restart=on-failure for steam, machines/xen-dom0.nix)
      extraConfig = ''
        pci_permissive = 1
        device_model_args_hvm = [ "-fw_cfg", "name=etc/pci-optionrom-exec,file=${optionRomExecOff}" ]
        on_reboot = "restart"
      '';
    };
    # Memory, vCPUs, home and the GPU (gpu = true) in vms.nix; PCI
    # passthrough needs the full memory at boot (no ballooning)
  };

  services = {
    # Its own base: no common-config (gamescope session on tty1)
    common-config.enable = false;
    qemuGuest.enable = true;
    xserver.videoDrivers = [ "nvidia" ];
    getty.autologinUser = "user";
    seatd = {
      enable = true;
      group = "seat";
    };
    dbus.enable = true;
    upower.enable = true;
    blueman.enable = true;
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
      "pci=realloc=on"
      "pci=assign-busses"
    ];
    extraModprobeConfig = ''
      options vfio-pci disable_idle_d3=1
      options nvidia-drm modeset=1 fbdev=1
    '';
    blacklistedKernelModules = [ "nouveau" ];
    kernelPackages = pkgs.linuxPackages_zen;
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = true;

      package = config.boot.kernelPackages.nvidiaPackages.stable;
      prime.offload.enable = false;
      prime.sync.enable = false;
      nvidiaSettings = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
    };
    bluetooth = {
      enable = true;
      settings = {
        General = {
          AutoEnable = true;
          FastConnectable = true;
        };
      };
    };
  };

  programs = {
    gamescope = {
      enable = true;
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
    };
    gamemode.enable = true;
  };

  security = {
    wrappers.bwrap = {
      source = "${pkgs.bubblewrap}/bin/bwrap";
      owner = "root";
      group = "root";
      setuid = true;
    };
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
    rtkit.enable = true;
  };

  environment = {
    loginShellInit = ''
      if [[ "$(tty)" = "/dev/tty1" ]]; then
        exec "$HOME/gs.sh" &> "$HOME/gs.log"
      fi
    '';
    systemPackages = with pkgs; [
      mangohud
      pciutils
      dbus
      vim
      btop
      protonup-rs
    ];
    sessionVariables = {
      TERM = "xterm-256color";
    };
    etc = {
      "gs.sh" = {
        mode = "0755";
        text = ''
          #!/usr/bin/env bash
          set -xeu pipefail

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

          exec gamescope "''${gamescopeArgs[@]}" -- steam "''${steamArgs[@]}"
        '';
      };
      "ssh_config".text = ''
        Host *
            StrictHostKeyChecking no
            UserKnownHostsFile /dev/null
      '';
      "MangoHud/MangoHud.conf".text = ''
        fps
        frametime
        frame_timing
        gpu_stats
        gpu_temp
        gpu_power
        vram
        position=top-left
        font_size=24
        background_alpha=0.35
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "L+ /home/user/gs.sh - - - - /etc/gs.sh"
    "L+ /home/user/.ssh/config - - - - /etc/ssh_config"
    "d /home/user/.config 0755 user users - -"
    "d /home/user/.config/MangoHud 0755 user users - -"
    "L+ /home/user/.config/MangoHud/MangoHud.conf - - - - /etc/MangoHud/MangoHud.conf"
  ];

  networking.networkmanager = {
    enable = true;
    settings = {
      main.no-auto-default = "*";
    };
  };

  users = {
    groups.users = { };
    groups.seat = { };
    users.user = {
      isNormalUser = true;
      group = "users";
      extraGroups = [
        "wheel"
        "video"
        "render"
        "input"
        "seat"
      ];
    };
  };
}
