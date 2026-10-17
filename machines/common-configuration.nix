{
  lib,
  config,
  inputs,
  vmRegistry,
  vmDefinitions,
  ...
}:
let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [
      (_final: prev: {
        inherit (prev.lixPackageSets.latest)
          nixpkgs-review
          nix-eval-jobs
          nix-fast-build
          colmena
          ;
      })
      # wprs: held modifiers follow the compositor (stuck Super, xen-migration.md);
      # wprsc keeps its title prefix on windows without a title (trust label
      # border in niri); clipboard isolation for the wprsd of the image domains (Whonix)
      (_final: prev: {
        wprs = prev.wprs.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../modules/wprs-modifier-sync.patch
            ../modules/wprs-title-prefix.patch
            (import ../modules/wprs-clipboard.nix { pkgs = prev; }).patch
          ];
        });
      })
    ];
  };
  maxVMs = 50;
  vfioPciIds = vmRegistry.hardware.pci.vfioIds or [ ];
  hostProfile = vmRegistry.hostProfile or { };
  cpuVendor = hostProfile.cpuVendor or "intel";
  dGpuVendor = hostProfile.dGpuVendor or null;
  blockedHostDrivers = hostProfile.blockedHostDrivers or { };

  iommuKernelParam =
    if cpuVendor == "intel" then
      "intel_iommu=on"
    else if cpuVendor == "amd" then
      "amd_iommu=on"
    else
      null;

  gpuBlacklistModules =
    if dGpuVendor == "nvidia" then
      [
        "nouveau"
        "nvidia"
        "nvidia_drm"
        "nvidia_modeset"
        "i2c_nvidia_gpu"
      ]
    else if dGpuVendor == "amd" then
      [ "amdgpu" ]
    else
      [ ];

  # Only with vfio ids (KVM). On Xen the dGPU goes to pciback when its VM
  # starts and only needs the blacklist below
  vfioPreSoftdeps =
    if vfioPciIds == [ ] then
      [ ]
    else if dGpuVendor == "nvidia" then
      [
        "softdep nvidia pre: vfio-pci"
        "softdep drm pre: vfio-pci"
        "softdep nouveau pre: vfio-pci"
      ]
    else if dGpuVendor == "amd" then
      [
        "softdep amdgpu pre: vfio-pci"
        "softdep drm pre: vfio-pci"
      ]
    else
      [ ];

  hostBlockedNicDrivers = blockedHostDrivers.nic or [ ];
  hostBlockedWifiDrivers = blockedHostDrivers.wifi or [ ];
  hostBlacklistedKernelModules =
    gpuBlacklistModules ++ hostBlockedNicDrivers ++ hostBlockedWifiDrivers;

  mkVmReservedUsbRule =
    device:
    let
      udev = device.udev or { };
      group = udev.group or "kvm";
      modePart = lib.optionalString (udev ? mode) '', MODE="${udev.mode}"'';
      udisksPart = lib.optionalString (udev.udisksIgnore or false
      ) '', ENV{UDISKS_IGNORE}="1", TAG-="uaccess"'';
    in
    ''SUBSYSTEM=="usb", ATTR{idVendor}=="${device.vendorId}", ATTR{idProduct}=="${device.productId}", GROUP="${group}"${modePart}${udisksPart}'';

  vmReservedUsbRules = lib.concatMapStringsSep "\n" mkVmReservedUsbRule (
    vmRegistry.hardware.usb.vmReserved or [ ]
  );
in
{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    plymouth.enable = true;
    initrd = {
      systemd.enable = true;
      kernelModules = lib.mkAfter (
        [
          "nvme"
          "sd_mod"
          "dm-crypt"
          "dm-mod"
        ]
        ++ lib.optionals (vfioPciIds != [ ]) [
          "vfio_pci"
          "vfio"
          "vfio_iommu_type1"
        ]
      );
      services.lvm.enable = true;
    };
    # Mainline kernel, no zen: dom0 gains little from its patches under Xen
    # (2026-10-14); 6.18 LTS could not drive the xmg panel plus two monitors,
    # latest tested on the hp (2026-10-15)
    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams =
      (lib.optionals (iommuKernelParam != null) [ iommuKernelParam ])
      ++ (lib.optionals (vfioPciIds != [ ]) [
        "iommu=pt"
        "vfio-pci.ids=${lib.concatStringsSep "," vfioPciIds}"
        "vfio-pci.disable_idle_d3=1"
      ]);

    extraModprobeConfig = lib.optionalString (vfioPciIds != [ ] || vfioPreSoftdeps != [ ]) ''
      ${lib.optionalString (vfioPciIds != [ ]) "options vfio-pci disable_idle_d3=1"}
      ${lib.optionalString (vfioPciIds != [ ] && vfioPreSoftdeps != [ ]) "\n"}
      ${lib.concatStringsSep "\n" vfioPreSoftdeps}
    '';

    blacklistedKernelModules = hostBlacklistedKernelModules;

    kernel.sysctl = {
      # see: https://github.com/wayland-transpositor/wprs?tab=readme-ov-file#system-tuning
      # and: https://wiki.archlinux.org/title/Sysctl#Increase_the_memory_dedicated_to_the_network_interfaces
      # Increase maximum and default socket buffer sizes for better network throughput
      "net.core.rmem_max" = 33554432; # Max receive buffer: 32 MB
      "net.core.wmem_max" = 33554432; # Max send buffer: 32 MB
      "net.core.rmem_default" = 2097152; # Default receive buffer: 2 MB
      "net.core.wmem_default" = 2097152; # Default send buffer: 2 MB
      "net.core.optmem_max" = 65536; # Max ancillary buffer: 64 KB

      # UDP minimum buffer sizes for receive and send
      "net.ipv4.udp_rmem_min" = 16384; # Min UDP receive buffer: 16 KB
      "net.ipv4.udp_wmem_min" = 16384; # Min UDP send buffer: 16 KB
    };
  };
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
      inherit vmRegistry;
    };
    users."nx" =
      { ... }:
      {
        imports = [
          ../home/home.nix
        ];
      };
  };

  # For proper XDG desktop integration
  # programs.niri adds the gnome portal (screencasting) and gnome-keyring
  # (Secret portal). niri's niri-portals.conf, plus the GTK file chooser:
  # the gnome one needs nautilus, which dom0 does not have (niri docs,
  # Important Software)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Access" = [ "gtk" ];
      "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      wl-clipboard
      wprs

      libnotify # Desktop notification library
      wl-clip-persist # Keep Wayland clipboard even after programs close (avoids crashes)
      xdg-utils # Collection of XDG desktop integration tools
      desktop-file-utils # for updating desktop database

      # sddm
      sddm-astronaut

      # Hardware
      brightnessctl # screen brightness control

      # Audio
      pavucontrol
      # playerctl
      fzf

      (import ../vms/copy-between-vms.nix { inherit pkgs lib vmRegistry; })
    ];

    variables = {
      NIXOS_OZONE_WL = "1";
    };

    sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
    };
  };

  programs = {
    niri.enable = true;
    nix-ld.enable = true;
    dconf.enable = true;
    # No nano: vim is the editor in dom0 too ($EDITOR), like in the VMs
    nano.enable = false;
    vim = {
      enable = true;
      defaultEditor = true;
    };
    ssh.startAgent = true;
  };

  # For polkit authentication
  security = {
    polkit.enable = true;
    pam.services.swaylock = { };
    rtkit.enable = true;
  };

  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
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

    # Host provides the internal L2 fabric; sys-net provides routing/NAT.
    network = {
      enable = true;
      netdevs = {
        "20-vm-internal" = {
          netdevConfig = {
            Name = "vm-internal";
            Kind = "bridge";
          };
        };
      };

      networks =
        (builtins.listToAttrs (
          map (index: {
            name = "30-vm${toString index}";
            value = {
              matchConfig.Name = "vm${toString index}";
              networkConfig = {
                Bridge = "vm-internal";
                ConfigureWithoutCarrier = true;
              };
              linkConfig.RequiredForOnline = "no";
            };
          }) (lib.genList (i: i + 1) maxVMs)
        ))
        // {
          "31-vm-router" = {
            matchConfig.Name = "vm-router";
            networkConfig = {
              Bridge = "vm-internal";
              ConfigureWithoutCarrier = true;
            };
            linkConfig.RequiredForOnline = "no";
          };

          "32-vm-internal" = {
            matchConfig.Name = "vm-internal";
            address = [ "10.0.0.254/24" ];
            routes = [
              {
                Destination = "0.0.0.0/0";
                Gateway = "10.0.0.253";
              }
            ];
            networkConfig.ConfigureWithoutCarrier = true;
            linkConfig.RequiredForOnline = "no";
          };

          "38-vnet-libvirt-ignore" = {
            matchConfig.Name = "vnet*";
            linkConfig.Unmanaged = "yes";
          };
        };
    };

    services.systemd-networkd-wait-online.enable = lib.mkForce false;
  };

  services = {
    # dom0 has no cpufreq under Xen (the hypervisor sets the clock): no
    # power-profiles-daemon/governor. Without ppd, nixos-hardware's
    # common-pc-laptop turns on TLP, which would touch runtime PM/ASPM of
    # devices, also passed-through ones (2026-10-14)
    tlp.enable = false;

    # programs.niri enables gnome-keyring (Secret portal); its gcr SSH agent
    # would take over SSH_AUTH_SOCK from programs.ssh.startAgent (above)
    gnome.gcr-ssh-agent.enable = false;

    dbus.enable = true;
    upower.enable = true;
    libinput.enable = true;

    displayManager.sddm = {
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
          DefaultSession = "niri.desktop";
        };
        Wayland = {
          EnableHiDPI = true;
        };
      };
    };

    # Sound
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber.enable = true;
      # If you want to use JACK applications, uncomment this
      # jack.enable = true;
      # No network audio: VMs get the native socket over the vchan relay
      # (/tmp/wprs-pulse in the VM), the former `ssh -R 4713` is gone
    };

    udev = {
      extraRules = ''
        # Keyboard
        SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="2303", GROUP="kvm"
        # Mouse
        SUBSYSTEM=="usb", ATTR{idVendor}=="260d", ATTR{idProduct}=="1121", GROUP="kvm"
      ''
      + lib.optionalString (vmReservedUsbRules != "") ''

        # VM-reserved USB devices are generated from vms/registry.nix
        ${vmReservedUsbRules}
      '';
      packages = [
        (pkgs.writeTextFile {
          name = "kaleidoskope-udev-rules";
          destination = "/etc/udev/rules.d/50-kaleidoskope.rules";
          text = ''
            # Kaleidoscope keyboards
            SUBSYSTEMS=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="2303", SYMLINK+="Atreus",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
            SUBSYSTEMS=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="2302", SYMLINK+="Atreus",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
          '';
        })
      ];
    };
  };

  # User
  users.users = {
    nx = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "kvm"
        "input"
      ];
    };
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

  # MicroVM Configuration
  microvm.host.enable = true;

  microvm.vms =
    let
      autostartFor = name: (vmRegistry.byName.${name}.autostart or false);
      selectedVms = vmRegistry.vms;
      # Group store images from the evaluated VMs below (registry `storeGroup`)
      storeGroups = import ../vms/store-groups.nix {
        inherit lib vmRegistry;
        inherit (inputs.microvm.lib) buildStoreDisk;
        vmSystems = builtins.mapAttrs (_: vm: vm.config) config.microvm.vms;
      };
    in
    builtins.listToAttrs (
      map (vm: {
        inherit (vm) name;
        value = {
          pkgs = null;
          config = {
            imports = [
              vmDefinitions.${vm.name}.module
              (storeGroups.moduleFor vm.name)
            ];
          };
          specialArgs = {
            inherit inputs vmRegistry;
          }
          // (vmDefinitions.${vm.name}.specialArgs or { });
          autostart = autostartFor vm.name;
          restartIfChanged = false;
        };
      }) selectedVms
    );

  # use cache
  nix = {
    package = pkgs.lixPackageSets.latest.lix;
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://microvm.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = [
        "nx"
      ];
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  networking.networkmanager = {
    enable = true;
    unmanaged = [
      "interface-name:vm*"
      "interface-name:vnet*"
    ];
  };

  system.stateVersion = "26.05";
}
