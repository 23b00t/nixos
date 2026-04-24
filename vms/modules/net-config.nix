{ lib, config, ... }:

with lib;

let
  cfg = config.services.net-config;

  defaultTapId = if cfg.index == null then null else "vm${toString cfg.index}";
  effectiveTapId = if cfg.tapId != null then cfg.tapId else defaultTapId;
  effectiveAddress4 =
    if cfg.address4 != null then
      cfg.address4
    else if cfg.index != null then
      "10.0.0.${toString cfg.index}/24"
    else
      null;
  effectiveGateway4 = if cfg.gateway4 != null then cfg.gateway4 else "10.0.0.253";
  needsOnLinkGatewayRoute = effectiveAddress4 != null && hasSuffix "/32" effectiveAddress4;
in
{
  options.services.net-config = {
    enable = mkEnableOption "Enable the VM network configuration module";

    index = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Legacy VM index used to derive tap id and IPv4 address.";
    };

    tapId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional explicit host-side tap id.";
    };

    mac = mkOption {
      type = types.str;
      description = "MAC address for the guest interface.";
    };

    interfaceName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional stable guest interface name.";
    };

    address4 = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional explicit IPv4 address with prefix length.";
    };

    gateway4 = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "IPv4 default gateway. Defaults to sys-net (10.0.0.253).";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
        "2620:fe::9"
      ];
      description = "DNS servers for the guest.";
    };
  };

  config = mkIf cfg.enable {
    networking.useNetworkd = true;

    assertions = [
      {
        assertion = effectiveAddress4 != null;
        message = "services.net-config requires either index or address4.";
      }
    ];

    microvm.interfaces = mkIf (effectiveTapId != null) [
      {
        id = effectiveTapId;
        type = "tap";
        mac = cfg.mac;
      }
    ];

    systemd.network.links = mkIf (cfg.interfaceName != null) {
      "10-net-config-link" = {
        matchConfig.MACAddress = cfg.mac;
        linkConfig.Name = cfg.interfaceName;
      };
    };

    systemd.network.networks."20-net-config" = {
      matchConfig.MACAddress = cfg.mac;
      address = [ effectiveAddress4 ];
      routes =
        optional (effectiveGateway4 != null && needsOnLinkGatewayRoute) {
          Destination = "${effectiveGateway4}/32";
          Scope = "link";
        }
        ++ optional (effectiveGateway4 != null) {
          Destination = "0.0.0.0/0";
          Gateway = effectiveGateway4;
        };
      networkConfig.DNS = cfg.dns;
    };
  };
}

