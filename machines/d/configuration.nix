# NixOS config

{ pkgs, inputs, ... }:
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
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.autoLogin = {
    enable = true;
    user = "yula";
  };

  networking.hostName = "machine";
  networking.firewall = {
    enable = true;
  };

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  environment.systemPackages = with pkgs; [
    wl-clipboard
    git
    vim
    gnupg
    pinentry
    wget
    gnome-shell
    gnome-control-center
    pciutils
    xwayland
  ];
  # Set the default editor to vim
  programs.vim.enable = true;
  environment.variables.EDITOR = "vim";
  # Set vim as default Editor
  programs.vim.defaultEditor = true;

  environment.gnome.excludePackages = (
    with pkgs;
    [
      epiphany # web browser
      gedit # text editor
    ]
  );

  users.users.yula = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
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

  # Time & Locals
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
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
  console.keyMap = "de";
  services.xserver.xkb.layout = "de";

  # zsh
  programs.zsh.enable = true;
  users.extraUsers.yula = {
    shell = pkgs.zsh;
  };
  users.defaultUserShell = pkgs.zsh;

  # gpg
  # programs.gnupg.agent = {
  #   enable = true;
  #   settings = {
  #     default-cache-ttl = 3600;
  #     max-cache-ttl = 7200;
  #   };
  # };
  #
  # # ssh
  # programs.ssh.startAgent = true;
  # security.pam.sshAgentAuth.enable = true;
  networking.useNetworkd = true;

  # use cache
  nix = {
    settings = {
      substituters = [
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
      trusted-users = [
        "root"
        "yula"
      ];
    };
  };

  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [
      "-L" # print build logs
    ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };

  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "02:00";
    randomizedDelaySec = "45min";
  };

  boot.loader.systemd-boot.configurationLimit = 3;

  services.openssh = {
    enable = true; # Service is available, but will not autostart
    startWhenNeeded = false; # Prevent autostart, manual start only
    allowSFTP = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      ChallengeResponseAuthentication = false;
      AllowUsers = [ "yula" ];
    };
    # Service will not start automatically. To start manually:
    #   sudo systemctl start sshd
    # To stop:
    #   sudo systemctl stop sshd
  };
}
