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
  # boot.initrd.systemd.enable = true;

  # GNOME Wayland (with PaperWM)
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.wayland = true;

  networking.hostName = "machine";
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "vm-net" ];
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
    gnome-shell
    gnome-control-center
    virt-manager
    libvirt
    qemu
    pciutils
    cloud-hypervisor
    virtiofsd
    zellij
    firefox # testing only
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
    extraGroups = [ "wheel" "networkmanager" "libvirtd" ];
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
  programs.ssh.startAgent = true;
  # security.pam.sshAgentAuth.enable = true;

  # microvm network
  networking.interfaces."vm-net".ipv4.addresses = [{
   address = "192.168.100.1";
   prefixLength = 24;
  }];

  networking.nat.enable = true;
  networking.nat.internalInterfaces = [ "vm-net" ];
  networking.nat.externalInterface = "enp0s20f0u2u3";
  boot.kernel.sysctl."net.ipv4.ip_forward" = true;

  # networking.firewall.allowedTCPPorts = [ 22 ];
}

