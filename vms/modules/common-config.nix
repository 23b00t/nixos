{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.services.common-config;
  defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
in
{
  options.services.common-config = {
    enable = mkEnableOption "Enable the common-config module";
    sshKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "SSH public key for the user.";
    };
    user = mkOption {
      type = types.str;
      default = "user";
      description = "Username for the main user.";
    };
    withDefaultPkgs = mkOption {
      type = types.bool;
      default = true;
      description = "Enable the default set of packages defined in default-pkgs.nix";
    };
  };

  config = mkIf cfg.enable {
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
        # DBus Forwarding
        StreamLocalBindUnlink yes
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

    users.users.${cfg.user} = {
      isNormalUser = true;
      group = "users";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = mkIf (cfg.sshKey != null) [ cfg.sshKey ];
    };

    environment.sessionVariables = {
      TERM = "xterm-256color";
      GTK_THEME = "Adwaita:dark";
      QT_QPA_PLATFORMTHEME = "gtk2";
      QT_STYLE_OVERRIDE = "Adwaita-Dark";
      GTK_CURSORS_THEME = "Bibata-Modern-Ice";
      XCURSOR_THEME = "Bibata-Modern-Ice";
      WAYLAND_CURSOR_THEME = "Bibata-Modern-Ice";
      WAYLAND_DISPLAY = "wayland-0";
    };

    fonts.packages = with pkgs; [
      nerd-fonts.fira-code
    ];

    environment.shellInit = ''
      if [ -n "$SSH_CONNECTION" ]; then
        export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/ssh_dbus.sock
      fi
    '';

    environment.etc."ssh_config".text = ''
      Host *
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
      Host 10.0.0.254 
          IdentitiesOnly yes
    '';

    systemd.tmpfiles.rules = [
      "d /home/${cfg.user} 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.ssh 0700 ${cfg.user} users -"
      "L+ /home/${cfg.user}/.ssh/config - - - - /etc/ssh_config"
    ];

    environment.systemPackages = mkIf cfg.withDefaultPkgs (mkBefore defaultPkgs);
  };
}
