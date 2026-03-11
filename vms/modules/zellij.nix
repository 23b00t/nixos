{
  config,
  lib,
  pkgs,
  ...
}:

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

    tabsKdlFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional override for zellij/layouts/tabs.kdl file.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.zellij ];

    environment.etc."zellij/config.kdl".source = cfg.configDir + "/config.kdl";
    environment.etc."zellij/plugins".source = cfg.configDir + "/plugins";
    environment.etc."zellij/layouts/tabs.swap.kdl".source = cfg.configDir + "/layouts/tabs.swap.kdl";
    environment.etc."zellij/layouts/tabs.kdl".source = lib.mkIf (
      cfg.tabsKdlFile != null
    ) cfg.tabsKdlFile;

    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/.config/zellij 0755 ${cfg.user} users -"
      "L+ /home/${cfg.user}/.config/zellij/config.kdl - - - - /etc/zellij/config.kdl"
      "d /home/${cfg.user}/.config/zellij/layouts 0755 ${cfg.user} users -"
      "L+ /home/${cfg.user}/.config/zellij/plugins - - - - /etc/zellij/plugins"
    ]
    ++ lib.optional (
      cfg.tabsKdlFile != null
    ) "L+ /home/${cfg.user}/.config/zellij/layouts/tabs.kdl - - - - ${cfg.tabsKdlFile}";
  };
}
