{
  lib,
  pkgs,
  sshKey ? null,
  ...
}:
{
  # boot.kernelParams = [
  #   "systemd.log_level=debug"
  #   "systemd.device-timeout=5s"
  # ];
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
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
  };

  # see: https://nateware.com/2013/04/06/linux-network-tuning-for-2013/
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      MaxSessions = 100;
      MaxStartups = "30:50:100";
      LoginGraceTime = 30;
    };
    extraConfig = ''
      # TCP Keepalive für stabile Verbindungen
      TCPKeepAlive yes
      ClientAliveInterval 60
      ClientAliveCountMax 3
      # Login-Beschleunigung
      UseDNS no
    '';
  };
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "100000";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "100000";
    }
  ];
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  users.groups.users = { };

  users.users.user = {
    isNormalUser = true;
    group = "users";
    extraGroups = [
      "wheel"
    ];
    # Only set authorizedKeys if sshKey is provided
    openssh.authorizedKeys.keys = lib.mkIf (sshKey != null) [ sshKey ];
  };

  environment.sessionVariables = {
    # Solves bug with hosts xterm-kitty handed to the vms
    TERM = "xterm-256color";
    # Dark theme for vms
    GTK_THEME = "Adwaita:dark";
    QT_QPA_PLATFORMTHEME = "gtk2";
    QT_STYLE_OVERRIDE = "Adwaita-Dark";
    # FIXME: Cursor theme for vms doesn't work yet
    GTK_CURSORS_THEME = "Bibata-Modern-Ice";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    WAYLAND_CURSOR_THEME = "Bibata-Modern-Ice";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  environment.etc."ssh_config".text = ''
    Host *
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    Host 10.0.0.254 
        IdentitiesOnly yes
  '';

  systemd.tmpfiles.rules = [
    "L+ /home/user/.ssh/config - - - - /etc/ssh_config"
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      23000
    ];
  };
}
