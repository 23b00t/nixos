{ config, lib, pkgs, ... }:

let
  cfg = config.services.zellij-env;
in
{
  options.services.zellij-env = {
    enable = lib.mkEnableOption "Zellij terminal multiplexer setup";

    user = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Target user for Zellij config and tmpfiles rules";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = ./zellij;
      description = "Directory containing Zellij config (config.kdl, layouts/, plugins/).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.zellij ];

    environment.etc."zellij".source = cfg.configDir;

    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/.config/zellij 0755 ${cfg.user} users -"
      "L+ /home/${cfg.user}/.config/zellij/config.kdl - - - - /etc/zellij/config.kdl"
      "L+ /home/${cfg.user}/.config/zellij/layouts - - - - /etc/zellij/layouts"
      "L+ /home/${cfg.user}/.config/zellij/plugins - - - - /etc/zellij/plugins"
    ];
  };
}
