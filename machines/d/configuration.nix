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

  networking.hostName = "machine";
  networking.firewall = {
    enable = true;
  };

  # Xen
  # Prerequestis
  boot.initrd.systemd.enable = true;
  # boot.initrd.kernelModules = [ "nvme" "sd_mod" "dm-crypt" ];
  # boot.initrd.kernelModules = [ "nvme" "sd_mod" "dm-crypt" "dm-mod" "i2c-hid" "i2c-hid-acpi" "hid-generic" "hid-multitouch" ];
  boot.initrd.kernelModules = [ 
    "nvme" 
    "sd_mod" 
    "dm-crypt" 
    "dm-mod"
    "i2c_hid"
    "i2c_hid_acpi"
    "i2c_i801"    # Intel I2C Controller
  ];
  boot.kernelParams = [
    "usbcore.autosuspend=-1"
    "xhci_hcd.quirks=270336"
    "intel_iommu=on"  # Änderung von 'off' zu 'on'
    "rd.debug"
    "irqpoll"
    "i2c_hid.polling_mode=1"
    "pci=nocrs"       # Versucht IRQ-Konflikte zu vermeiden
  ];
  boot.initrd.services.lvm.enable = true;
  hardware.i2c.enable = true;

  services.upower.enable = true;  # Wichtig für einige ACPI-Funktionen

  # Xen-Konfiguration
  virtualisation.xen = {
    enable = true;
    efi.bootBuilderVerbosity = "info";
    bootParams = [
      "vga=ask"
      "dom0=hvm"      # Änderung von 'pvh' zu 'hvm'
      "iommu=verbose"
      "acpi=force"
      "i2c_designware.poll_mode=1"
      "xen-pciback.hide=(00:15.0),(00:15.1)"  # I2C Controller
    ];
    dom0Resources = {
      memory = 8192;
      maxVCPUs = 4;
    };
  };

  # Zusätzliche Hardware-Unterstützung
  services.xserver.libinput = {
    enable = true;
    touchpad = {
      disableWhileTyping = true;
      naturalScrolling = true;
      tapping = true;
    };
  };

  # Kernel-Module beim Start laden
  boot.extraModprobeConfig = ''
    options i2c_hid poll_interval=1
    options i2c_hid_acpi poll_interval=1
  '';

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
    extraGroups = [ "wheel" "networkmanager" ];
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

