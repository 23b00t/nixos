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
  boot.initrd.kernelModules = [ "tpm_tis" ];
  # Dom0
  virtualisation.xen = {
    enable = true;
    efi.bootBuilderVerbosity = "info"; # Adds a handy report that lets you know which Xen boot entries were created.
    bootParams = [
      "vga=ask" # Useful for non-headless systems with screens bigger than 640x480.
      "dom0=pvh" # Uses the PVH virtualisation mode for the Domain 0, instead of PV.
    ];
    dom0Resources = {
      memory = 1024; # Only allocates 1GiB of memory to the Domain 0, with the rest of the system memory being freely available to other domains.
      maxVCPUs = 2; # Allows the Domain 0 to use, at most, two CPU cores.
    };
  };

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
        "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
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

  # ssh
  programs.ssh.startAgent = true;
  # security.pam.sshAgentAuth.enable = true;

  networking.useNetworkd = true;

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

