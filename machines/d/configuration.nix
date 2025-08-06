# NixOS config

{ config, lib, pkgs, ... }:
{
  imports = [ 
    ./hardware-configuration.nix 
  ];

  # Switch to minimal channel for host?
  system.stateVersion = "25.05";
  
  # Bootloader EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.efi.efiSysMountPoint = "/boot";  

  # GNOME Wayland (with PaperWM)
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  # Xen
  # Prerequestis
  # nixpkgs.config.allowUnfree = true;
  # Grundlegende Boot- und LVM-Konfiguration
  boot.initrd = {
    systemd.enable = true;
    kernelModules = [ 
      "nvme" 
      "sd_mod" 
      "dm-crypt" 
      "dm-mod"
    ];
    services.lvm.enable = true;
  };

  # Kernel-Parameter für I2C und Interrupts
#   boot.kernelParams = [
#     "intel_iommu=on"
#     "iommu.passthrough=1"
#     "irqpoll"
#     "pci=realloc"
#     "i2c_designware.sync_mode=1"  # Synchroner Modus für DesignWare I2C
#   ];

  # Explizite Kernel-Module für I2C
#   boot.kernelModules = [
#     "i2c_hid"
#     "i2c_hid_acpi"
#     "i2c_i801"
#     "i2c_designware_platform"
#     "i2c_designware_core"
#   ];

  # Xen-Konfiguration
  virtualisation.xen = {
    enable = true;
    bootParams = [
      "dom0=pvh"
      "vga=ask"
#       "iommu=1"
#       "acpi=force"
    ];
    dom0Resources = {
      memory = 8192;
      maxVCPUs = 2;
    };
  };

  # Hardware-Unterstützung
#   hardware = {
#     enableAllFirmware = true;
#     i2c.enable = true;
#   };

  # Input-Unterstützung
  # services.xserver.libinput.enable = true;

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
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
    gnome-control-center
    zellij
    firefox # testing only
    xwayland
    waypipe
    xen
    qemu_xen
  ];
  # Set the default editor to vim
  programs.vim.enable = true;
  environment.variables.EDITOR = "vim";
  # Set vim as default Editor
  programs.vim.defaultEditor = true;

  # programs.gnome-terminal.enable = true;

  environment.gnome.excludePackages = (with pkgs; [
    epiphany # web browser
    gedit # text editor
  ]);

  # User
  users.users.nx = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "kvm" "xen" ];
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
  };

  # Bluetooth

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
  console.keyMap = "en";
  services.xserver.xkb.layout = "us,de";
  services.xserver.xkb.variant = "intl";
  services.xserver.xkb.options = "grp:alt_shift_toggle";

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


  networking = {
    hostName = "machine";
    firewall.enable = true;

    interfaces.enp0s20f0u2u3.useDHCP = false;

    bridges.br0.interfaces = [ "enp0s20f0u2u3" ];
    interfaces.br0 = {
      useDHCP = false;
      ipv4.addresses = [ {
        address = "192.168.0.254";
        prefixLength = 24;
      } ];
    };

    defaultGateway = "192.168.0.1";
    # nameservers = [ "8.8.8.8" "192.168.0.1" ];
  };

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
      trusted-users = [ "root" "nx" ];
    };
  };
}

