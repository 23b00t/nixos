{
  lib,
  config,
  inputs,
  vmRegistry,
  vmFlakes,
  ...
}:
let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  maxVMs = 23;
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
  # Switch govenor with: sudo cpupower frequency-set -g performance
  # Get infos: cpupower frequency-info
  services.power-profiles-daemon.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";

  nixpkgs.pkgs = pkgs;

  imports = [
    inputs.microvm.nixosModules.host
    inputs.home-manager.nixosModules.home-manager

    # Hardware Configuration - Uncomment lines that match your hardware
    # Run `lshw -short` or `lspci` to identify your hardware

    # GPU Configuration (choose one):
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia

    # Additional Hardware Modules - Uncomment based on your system type:
    inputs.nixos-hardware.nixosModules.common-hidpi # High-DPI displays
    inputs.nixos-hardware.nixosModules.common-pc-laptop # Laptops
    inputs.nixos-hardware.nixosModules.common-pc-ssd # SSD storage
    # ../modules/steam-vm-image.nix
    # inputs.flatpaks.nixosModules.default
    ../modules/dbus-proxy.nix
  ];

  # Home Manager Configuration - manages user-specific configurations (dotfiles, themes, etc.)
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hostname = config.networking.hostName;
    };
    users."nx" =
      { ... }:
      {
        imports = [
          ../home/home.nix
        ];
      };
  };

  networking = {
    # hostName = "machine";
    # TODO: Use nftables - check rules
    # nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        9003
        631
      ];
      extraCommands = ''
        iptables -A INPUT -p tcp --dport 22 -s 10.0.0.9 -j ACCEPT
        iptables -A INPUT -p tcp --dport 22 -j DROP
      '';
      extraStopCommands = ''
        iptables -D INPUT -p tcp --dport 22 -s 10.0.0.9 -j ACCEPT || true
        iptables -D INPUT -p tcp --dport 22 -j DROP || true
      '';
      # TODO: Test to remove after Docker has been removed
      # Erlaubt Traffic auf der Bridge (nötig wegen Docker/br_netfilter)
      trustedInterfaces = [ "virbr2" ];
    };
  };
  services.openssh = {
    enable = true;
    # listenAddresses = [
    #   {
    #     addr = "10.0.0.0";
    #     port = 22;
    #   }
    # ];
    settings.PermitRootLogin = "no";
  };
  services.fail2ban.enable = true;

  # TODO: Check what should be done by home-manager
  environment.systemPackages = with pkgs; [
    # Flakes clones its dependencies through the git command,
    # so git must be installed first
    kitty
    wl-clipboard
    vim
    gnupg
    pinentry-curses
    wget
    virt-manager
    libvirt
    qemu
    cloud-hypervisor
    virtiofsd
    zellij
    shadow
    wprs
    remmina
    virt-viewer

    libnotify # Desktop notification library
    wl-clip-persist # Keep Wayland clipboard even after programs close (avoids crashes)
    polkit_gnome # authentication agent for privilege escalation
    dbus # inter-process communication daemon
    upower # power management/battery status daemon
    mesa # OpenGL implementation and GPU drivers
    dconf # configuration storage system
    dconf-editor # dconf editor
    xdg-utils # Collection of XDG desktop integration tools
    desktop-file-utils # for updating desktop database
    hicolor-icon-theme # Base fallback icon theme
    wayland # for wayland support
    egl-wayland # for wayland support
    xwayland # for x11 support
    coreutils # coreutils implementation
    hypridle

    # sddm
    sddm-astronaut

    # Network
    networkmanager
    networkmanagerapplet

    # Hardware
    brightnessctl # screen brightness control
    ntfs3g # ntfs support
    exfat # exFAT support
    libinput # libinput library
    lm_sensors # system sensors
    pciutils # pci utils

    # Audio
    bluez
    bluez-tools
    blueman
    pipewire
    wireplumber
    pavucontrol
    pamixer
    # playerctl
    git
    fzf

    (import ../vms/copy-between-vms.nix { inherit pkgs lib; })
  ];

  environment.variables = {
    NIXOS_OZONE_WL = "1";
  };

  programs.hyprland = {
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
    enable = true;
    withUWSM = true;
  };

  programs.nix-ld.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };

  services = {
    dbus.enable = true;

    upower.enable = true;
    libinput.enable = true;
  };

  programs.dconf.enable = true;
  programs.vim.enable = true;
  environment.variables.EDITOR = "vim";

  # For polkit authentication
  security.polkit.enable = true;
  security.pam.services.swaylock = { };
  security.rtkit.enable = true;
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # For proper XDG desktop integration
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # sddm
  # Add this section to ensure cursor theme is properly loaded
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  services.displayManager.sddm = {
    enable = true;
    theme = "sddm-astronaut-theme";
    wayland = {
      enable = true;
    };
    extraPackages = with pkgs.kdePackages; [
      qtsvg
      qtmultimedia
      qtvirtualkeyboard
    ];
    settings = {
      Theme = {
        CursorTheme = "Bibata-Modern-Ice";
        CursorSize = "24";
      };
      General = {
        # Set default session globally
        DefaultSession = "hyprland.desktop";
      };
      Wayland = {
        EnableHiDPI = true;
      };
    };
  };

  # User
  users.groups.tun = { };

  users.users = {
    nx = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "libvirtd"
        "tun"
        "docker"
        "kvm"
        "input"
      ];
    };
    microvm = {
      extraGroups = [ "tun" ];
    };
  };

  # Sound

  ## Remove sound.enable or set it to false if you had it set previously, as sound.enable is only meant for ALSA-based configurations

  services.pulseaudio.enable = false;

  services = {
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber = {
        enable = true;
        extraConfig.bluetoothEnhancements = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = [
              "hsp_hs"
              "hsp_ag"
              "hfp_hf"
              "hfp_ag"
            ];
          };
        };

      };
      # If you want to use JACK applications, uncomment this
      # jack.enable = true;
      # Netzwerk-Audio aktivieren
      # NOTE: Problems? -> ss -tulpn | grep 4713 -> nothing? ->
      # systemctl --user restart pipewire pipewire-pulse
      extraConfig.pipewire-pulse = {
        "92-network" = {
          "pulse.properties" = {
            "server.address" = [
              "tcp:4713"
              "unix:native"
            ];
            "auth-anonymous" = true;
            "auth-ip-acl" = "127.0.0.1;10.0.0.0/24";
          };
        };
      };
    };
    blueman.enable = true;
  };

  # networking.wireless.enable = true;

  # Time & Locals
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  # i18n.extraLocales = "de_DE.UTF-8/UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_ADDRESS = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    # https://www.reddit.com/r/NixOS/comments/11be3cy/i_need_some_help_changing_the_system_language/
  };

  virtualisation.libvirtd.enable = true;
  # virtualisation.spiceUSBRedirection.enable = true;

  systemd.services."libvirt-default-net" = {
    description = "Start libvirt default network";
    wantedBy = [ "multi-user.target" ];
    wants = [ "libvirtd.service" ];
    after = [ "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "-${pkgs.libvirt}/bin/virsh net-start default";
      RemainAfterExit = true;
    };
  };
  programs.virt-manager.enable = true;

  # TODO: Check if this is done in home-manager already
  # zsh
  programs.zsh.enable = true;
  users.extraUsers.nx = {
    shell = pkgs.zsh;
  };
  users.defaultUserShell = pkgs.zsh;

  # gpg
  programs.gnupg.agent = {
    enable = true;
    settings = {
      default-cache-ttl = 3600;
      max-cache-ttl = 7200;
    };
  };

  # MicroVM Configuration
  microvm.host.enable = true;

  microvm.vms =
    let
      # Helper to read autostart flag from registry by name.
      autostartFor = name: (vmRegistry.byName.${name}.autostart or false);

      # If you do not want all registry VMs to be microvms on this host,
      # filter vmRegistry.vms here.
      selectedVms = vmRegistry.vms;
    in
    builtins.listToAttrs (
      map (vm: {
        name = vm.name;
        value = {
          flake = vmFlakes.${vm.name};
          autostart = autostartFor vm.name;
        };
      }) selectedVms
    );

  programs.ssh.startAgent = true;
  # networking.useNetworkd = true;
  # Generiere Netzwerke für alle VMs
  # Netzwerke für Standard-VMs (10.0.0.x)
  systemd.network.networks =
    (builtins.listToAttrs (
      map (index: {
        name = "30-vm${toString index}";
        value = {
          matchConfig.Name = "vm${toString index}";
          # Host-Adresse für die P2P Verbindung
          address = [
            "10.0.0.0/32" # Host auf diesem Interface
            "10.0.0.254/32" # Feste Host-IP für alle VMs
            "fec0::/128"
            "fec0::ff/128" # Feste Host-IPv6 für alle VMs
          ];
          # Route zur VM
          routes = [
            { Destination = "10.0.0.${toString index}/32"; }
            { Destination = "fec0::${lib.toHexString index}/128"; }
          ];
          networkConfig = {
            IPv4Forwarding = true;
            IPv6Forwarding = true;
          };
        };
      }) (lib.genList (i: i + 1) maxVMs)
    ))
    // {
      # IMPORTANT: Ignore Tor interfaces for VMs
      "35-vm11-tor-ignore" = {
        matchConfig.Name = "vm11-tor";
        linkConfig.Unmanaged = "yes";
      };
    };

  # NAT only for 4 VMs
  networking.nat =
    let
      vmRegistry = import ../vms/registry.nix;
    in
    {
      enable = true;
      internalIPs = map (ip: "${ip}/32") vmRegistry.natIPs;
      # externalInterface = "wlo1";
    };

  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # use cache
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://microvm.cachix.org"
        "https://hyprland.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = [
        "root"
        "nx"
      ];
    };
  };

  systemd.services.retrigger-vm11-tor-udev = {
    description = "Retrigger udev for vm11-tor after boot";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/udevadm trigger --action=add /sys/class/net/vm11-tor";
    };
  };

  services.udev.extraRules = ''
    KERNEL=="tun", GROUP="tun", MODE="0660", OPTIONS+="static_node=tun"
    # Udev-Regel, die feuert, sobald vm11-tor auftaucht (Hotplug-sicher)
    SUBSYSTEM=="net", ACTION=="add", KERNEL=="vm11-tor", RUN+="${pkgs.iproute2}/bin/ip link set dev $name master virbr2", RUN+="${pkgs.iproute2}/bin/ip link set dev $name up"
    # Keyboard
    SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="2303", GROUP="kvm"
    # Mouse
    SUBSYSTEM=="usb", ATTR{idVendor}=="093a", ATTR{idProduct}=="2533", GROUP="kvm"
  '';
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "kaleidoskope-udev-rules";
      destination = "/etc/udev/rules.d/50-kaleidoskope.rules";
      text = ''
        # Kaleidoscope keyboards
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="2303", SYMLINK+="Atreus",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="2302", SYMLINK+="Atreus",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="2301", SYMLINK+="Model01",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="2300", SYMLINK+="Model01",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="3496", ATTRS{idProduct}=="0006", SYMLINK+="Model100",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="3496", ATTRS{idProduct}=="0005", SYMLINK+="Model100",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="3496", ATTRS{idProduct}=="00a1", SYMLINK+="Preonic",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="3496", ATTRS{idProduct}=="00a3", SYMLINK+="Preonic",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="3496", ATTRS{idProduct}=="00a0", SYMLINK+="Preonic",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="3496", ATTRS{idProduct}=="00a3", SYMLINK+="Preonic",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
      '';
    })
  ];

  # Printer
  services.printing = {
    enable = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  networking.networkmanager = {
    enable = true;
    unmanaged = [
      "interface-name:vm*"
      "interface-name:virbr*"
    ];
  };

  systemd.network.enable = true;

  system.stateVersion = "26.05";
}
