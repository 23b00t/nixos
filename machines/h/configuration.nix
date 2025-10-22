# NixOS config

{
  lib,
  pkgs,
  ...
}:
let
  maxVMs = 8;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Switch to minimal channel for host?
  system.stateVersion = "25.05";

  # Bootloader EFI
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-1d537a05-447a-4a7d-b5c0-2813b4a6de1d".device =
    "/dev/disk/by-uuid/1d537a05-447a-4a7d-b5c0-2813b4a6de1d";

  # boot.loader.efi.efiSysMountPoint = "/boot";
  # boot.initrd.systemd.enable = true;

  # GNOME Wayland (with PaperWM)
  # services.displayManager.gdm.enable = true;
  # services.displayManager.gdm.wayland = true;
  # services.desktopManager.gnome.enable = true;
  # services.gnome.gcr-ssh-agent.enable = false;

  # networking.hostName = "machine";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 9003 ];
  };

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  environment.systemPackages = with pkgs; [
    # Flakes clones its dependencies through the git command,
    # so git must be installed first
    kitty
    wl-clipboard
    git
    vim
    gnupg
    pinentry
    wget
    # gnome-shell
    # gnome-control-center
    virt-manager
    libvirt
    qemu
    pciutils
    cloud-hypervisor
    virtiofsd
    zellij
    # xwayland
    waypipe
  ];
  # Set the default editor to vim
  programs.vim.enable = true;
  environment.variables.EDITOR = "vim";
  # Set vim as default Editor
  programs.vim.defaultEditor = true;

  # programs.gnome-terminal.enable = true;

  # environment.gnome.excludePackages = (
  #   with pkgs;
  #   [
  #     epiphany # web browser
  #     gedit # text editor
  #   ]
  # );

  # User
  users.groups.tun = { };

  services.udev.extraRules = ''
    KERNEL=="tun", GROUP="tun", MODE="0660", OPTIONS+="static_node=tun"
  '';
  users.users.nx = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "tun"
      "docker"
      "kvm"
    ];
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
    #jack.enable = true;
    # Netzwerk-Audio aktivieren
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
  # i18n.defaultLocale = "en_US.UTF-8";
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
  services.xserver.xkb.layout = "us,de";
  services.xserver.xkb.variant = "intl";
  services.xserver.xkb.options = "grp:alt_shift_toggle";

  virtualisation.libvirtd.enable = true;
  systemd.services."libvirt-default-net" = {
    description = "Start libvirt default network";
    wantedBy = [ "multi-user.target" ];
    wants = [ "libvirtd.service" ];
    after = [ "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.libvirt}/bin/virsh net-start default";
      # Doesn't work as expected. Should only start the service if it is not running
      # ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.libvirt}/bin/virsh net-info default | grep -q active || ${pkgs.libvirt}/bin/virsh net-start default'";
      RemainAfterExit = true;
    };
  };
  programs.virt-manager.enable = true;

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

  # ssh
  # programs.ssh.startAgent = true;
  # security.pam.sshAgentAuth.enable = true;

  # microvm network
  # networking.interfaces."vm-net".ipv4.addresses = [{
  # address = "192.168.100.1";
  # prefixLength = 24;
  # }];

  # networking.nat.enable = true;
  # networking.nat.internalInterfaces = [ "vm-net" ];
  # networking.nat.externalInterface = "enp0s20f0u2u3";
  # boot.kernel.sysctl."net.ipv4.ip_forward" = true;

  # networking.firewall.allowedTCPPorts = [ 22 ];
  networking.useNetworkd = true;

  systemd.network.networks = builtins.listToAttrs (
    map (index: {
      name = "30-vm${toString index}";
      value = {
        matchConfig.Name = "vm${toString index}";
        # Host's addresses
        address = [
          "10.0.0.0/32"
          "fec0::/128"
        ];
        # Setup routes to the VM
        routes = [
          {
            Destination = "10.0.0.${toString index}/32";
          }
          {
            Destination = "fec0::${lib.toHexString index}/128";
          }
        ];
        # Enable routing
        networkConfig = {
          IPv4Forwarding = true;
          IPv6Forwarding = true;
        };
      };
    }) (lib.genList (i: i + 1) maxVMs)
  );
  networking.nat = {
    enable = true;
    internalIPs = [ "10.0.0.0/24" ];
    # Change this to the interface with upstream Internet access
    externalInterface = "enp0s20f0u2u3";
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

  virtualisation = {
    docker = {
      enable = true;
      # Für rootless Docker (optional)
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
      # BuildX-Plugin aktivieren
      enableOnBoot = true; # Docker beim Systemstart starten
      extraOptions = "--experimental"; # Experimentelle Features aktivieren
      extraPackages = [ pkgs.docker-buildx ]; # BuildX-Plugin hinzufügen
    };
    podman = {
      enable = true;
      # Keine Docker-Kompatibilität, wenn Docker selbst installiert ist
      dockerCompat = false;
    };
  };

  hydenix = {
    enable = true; # enable hydenix - required, default false
    hostname = "machine"; # hostname
    timezone = "Europe/Berlin"; # timezone
    locale = "en_US.UTF-8"; # locale
    # hm.enable = true;
  };
}
