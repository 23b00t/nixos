{
  lib,
  inputs,
  ...
}:
let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [
      inputs.hydenix.overlays.default
      # Webcord with new Electron version
      # (final: prev: {
      #   webcord = prev.webcord.override {
      #     electron_36 = prev.electron_38;
      #   };
      # })
    ];
  };
  devices = [
    "10de:2d19" # NVIDIA RTX 5060 Max-Q (VGA)
    "10de:22eb" # NVIDIA RTX 5060 Audio
  ];
  maxVMs = 14;
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

  # Switch govenor with: sudo cpupower frequency-set -g performance
  # Get infos: cpupower frequency-info
  services.power-profiles-daemon.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     START_CHARGE_THRESH_BAT0 = 40;
  #     STOP_CHARGE_THRESH_BAT0 = 80;
  #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #     CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
  #     CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
  #   };
  # };

  # On battery specialisation
  # specialisation = {
  #   on-the-go.configuration = {
  #     system.nixos.tags = [ "on-the-go" ];
  #     hardware.nvidia = {
  #       prime.offload.enable = lib.mkForce true;
  #       prime.offload.enableOffloadCmd = lib.mkForce true;
  #       prime.sync.enable = lib.mkForce false;
  #     };
  #     # powerManagement.cpuFreqGovernor = lib.mkForce "powersave";
  #     # home-manager.users."nx".hydenix.hm.hyprland.monitors.overrideConfig = lib.mkForce ''
  #     #   monitor=eDP-1,2560x1600@60.00,0x0,1
  #     # '';
  #   };
  # };

  nixpkgs.pkgs = pkgs; # Set pkgs for hydenix globally

  imports = [
    # hydenix inputs - Required modules, don't modify unless you know what you're doing
    inputs.hydenix.inputs.home-manager.nixosModules.home-manager
    inputs.hydenix.nixosModules.default
    inputs.microvm.nixosModules.host
    ./hardware-configuration.nix # Auto-generated hardware config

    # Hardware Configuration - Uncomment lines that match your hardware
    # Run `lshw -short` or `lspci` to identify your hardware

    # GPU Configuration (choose one):
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia

    # CPU Configuration (choose one):
    inputs.nixos-hardware.nixosModules.common-cpu-intel # Intel CPUs

    # Additional Hardware Modules - Uncomment based on your system type:
    inputs.nixos-hardware.nixosModules.common-hidpi # High-DPI displays
    inputs.nixos-hardware.nixosModules.common-pc-laptop # Laptops
    inputs.nixos-hardware.nixosModules.common-pc-ssd # SSD storage
    # ../modules/steam-vm-image.nix
    inputs.flatpaks.nixosModules.default
  ];

  # steamVmImage = {
  #   enable = true;
  #   dataDiskSize = "200G";
  # };

  # hardware.nvidia = {
  #   open = true; # For newer cards, you may want open drivers
  #   modesetting.enable = true;
  #   # Enable the Nvidia settings menu,
  #   # accessible via `nvidia-settings`.
  #   nvidiaSettings = true;
  #   #      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
  #   #      # Enable this if you have graphical corruption issues or application crashes after waking
  #   #      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
  #   #      # of just the bare essentials.
  #   powerManagement.enable = false;
  #
  #   # Fine-grained power management. Turns off GPU when not in use.
  #   # Experimental and only works on modern Nvidia GPUs (Turing or newer).
  #   powerManagement.finegrained = false;
  #   prime = {
  #     # For hybrid graphics (laptops), configure PRIME:
  #     # nix shell "nixpkgs#lshw"; sudo lshw -c display (outputs hex, convert to decimal and strip leading zeros)
  #     intelBusId = "PCI:0:2:0"; # if you have intel graphics
  #     nvidiaBusId = "PCI:2:0:0";
  #     # It is an either-or decision
  #     offload.enable = false; # Or disable PRIME offloading if you don't care
  #     sync.enable = true; # Enable PRIME sync for smoother rendering
  #   };
  # };

  # Home Manager Configuration - manages user-specific configurations (dotfiles, themes, etc.)
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users."nx" =
      { ... }:
      {
        imports = [
          inputs.hydenix.homeModules.default
          ../home/home.nix # Your custom home-manager modules (configure hydenix.hm here!)
        ];
      };
  };

  # User Account Setup - REQUIRED: Change "hydenix" to your desired username (must match above)
  networking = {
    hostName = "machine";
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

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
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
    xwayland
    shadow
    wprs
    remmina
    virt-viewer

    flatpak

    (import ../vms/copy-between-vms.nix { inherit pkgs; })
  ];

  programs.vim.enable = true;
  environment.variables.EDITOR = "vim";

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
  ## rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
    # Netzwerk-Audio aktivieren
    # NOTE: Problems? -> ss -tulpn | grep 4713 -> nothing? ->
    # systemctl --user restart pipewire pipewire-pulse
    configPackages = [
      (pkgs.writeTextDir "share/pipewire/pipewire-pulse.conf.d/92-network.conf" ''
        pulse.cmd = [
          { cmd = "load-module" args = "module-native-protocol-tcp auth-ip-acl=127.0.0.1,10.0.0.0/24 port=4713" }
        ]
      '')
    ];
  };

  # Bluetooth

  services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = {
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

  networking.networkmanager.enable = true;
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

  # Keyboard layout
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "intl";
  services.xserver.xkb.options = "grp:alt_shift_toggle";

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
    # is set by hydenix to true
    enableSSHSupport = lib.mkForce false;
    settings = {
      default-cache-ttl = 3600;
      max-cache-ttl = 7200;
    };
  };

  # MicroVM Configuration
  microvm.host.enable = true;

  microvm.vms = {
    irc = {
      flake = inputs.irc-vm;
    };
    nvim = {
      flake = inputs.nvim-vm;
    };
    chat = {
      flake = inputs.chat-vm;
    };
    office = {
      flake = inputs.office-vm;
      autostart = false;
    };
    music = {
      flake = inputs.music-vm;
    };
    net = {
      flake = inputs.net-vm;
    };
    net-private = {
      flake = inputs.net-private-vm;
      autostart = false;
    };
    wine = {
      flake = inputs.wine-vm;
      autostart = false;
    };
    kali = {
      flake = inputs.kali-vm;
      autostart = false;
    };
    vault = {
      flake = inputs.vault-vm;
      autostart = false;
    };
    # test = {
    #   flake = inputs.test-vm;
    #   autostart = false;
    # };
    steam = {
      flake = inputs.steam-vm;
      autostart = false;
    };
    godot = {
      flake = inputs.godot-vm;
      autostart = false;
    };
  };
  programs.ssh.startAgent = true;
  networking.useNetworkd = true;
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
  networking.nat = {
    enable = true;
    internalIPs = [
      "10.0.0.1/32"
      "10.0.0.2/32"
      "10.0.0.3/32"
      "10.0.0.4/32"
      "10.0.0.5/32"
      "10.0.0.6/32"
      "10.0.0.7/32"
      "10.0.0.8/32"
      "10.0.0.12/32"
      "10.0.0.13/32"
    ];
    # externalInterface = "wlo1";
  };

  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # use cache
  nix = {
    settings = {
      substituters = [
        "https://cache.nixos.org"
        "https://microvm.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "microvm.cachix.org-1:oXnBs9THCoQI4PiXLm2ODWyptDIrQ2NYjmJfUfpGqMI="
      ];
      trusted-users = [
        "root"
        "nx"
      ];
    };
  };

  # security.wrappers.virtiofsd = {
  #   source = "${pkgs.virtiofsd}/bin/virtiofsd";
  #   capabilities = "cap_chown+ep";
  #   owner = "root";
  #   group = "root";
  #   permissions = "0755";
  # };

  # Hydenix Configuration - Main configuration for the Hydenix desktop environment
  hydenix = {
    enable = true; # Enable Hydenix modules
    # Basic System Settings (REQUIRED):
    hostname = "machine"; # REQUIRED: Set your computer's network name (change to something unique)
    timezone = "Europe/Berlin"; # REQUIRED: Set timezone (examples: "America/New_York", "Europe/London", "Asia/Tokyo")
    locale = "en_US.UTF-8"; # REQUIRED: Set locale/language (examples: "en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8")

    audio.enable = true; # enable audio module
    boot = {
      enable = false; # enable boot module
    };
    gaming.enable = true; # enable gaming module
    hardware.enable = true; # enable hardware module
    network.enable = true; # enable network module
    nix.enable = true; # enable nix module
    sddm.enable = true; # enable sddm module

    system.enable = true; # enable system module
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
    # KVM Group Access for USB Devices for Webcam pass through to MicroVM
    SUBSYSTEM=="usb", ATTR{idVendor}=="2b7e", ATTR{idProduct}=="c906", GROUP="kvm"
    # Keyboard
    SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="2303", GROUP="kvm"
    # Mouse
    SUBSYSTEM=="usb", ATTR{idVendor}=="093a", ATTR{idProduct}=="2533", GROUP="kvm"
    # Intel AX211 Bluetooth
    SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", GROUP="kvm", MODE="0660"
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

  # for static linked binaries in nvim
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ icu ];

  services.flatpak = {
    enable = true;
    # flatpakDir = "/home/nx/.local/share/flatpak";
    remotes = {
      "flathub" = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      "flathub-beta" = "https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo";
    };
    packages = [
      "flathub:app/org.godotengine.Godot/x86_64/stable"
    ];
  };

  # Steam VM CPU pinning
  systemd.services."microvm@steam".serviceConfig.CPUAffinity = "0 1 2 3 4 5 6 7 8 9";

  # System Version - Don't change unless you know what you're doing (helps with system upgrades and compatibility)
  system.stateVersion = "25.05";
}
