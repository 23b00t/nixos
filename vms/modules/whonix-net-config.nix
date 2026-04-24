{ lib, config, ... }:

with lib;

let
  cfg = config.services.whonix-net-config;
  hexId = lib.toHexString cfg.id;
  hexTorId = lib.toHexString (cfg.id + 1);
  idStr = toString cfg.id;
  torIpSuffix = toString (10 + cfg.id);
in
{
  options.services.whonix-net-config = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Whonix network configuration";
    };
    id = mkOption {
      type = types.int;
      description = "Unique index for network configuration";
    };
  };

  config = mkIf cfg.enable {
    networking.useNetworkd = true;

    systemd.network.networks."10-ssh" = {
      matchConfig.MACAddress = "02:00:00:00:00:0${hexId}";
      address = [ "10.0.0.${idStr}/24" ];
      routes = [
        {
          Destination = "10.0.0.0/24";
          Scope = "link";
        }
      ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
        DNSDefaultRoute = false;
      };
      linkConfig.RequiredForOnline = "no";
    };

    systemd.network.networks."20-tor" = {
      matchConfig.MACAddress = "02:00:00:00:00:0${hexTorId}";
      address = [ "10.152.152.${torIpSuffix}/18" ];
      routes = [
        {
          Destination = "0.0.0.0/0";
          Gateway = "10.152.152.10";
        }
      ];
      networkConfig = {
        DNS = [ "10.152.152.10" ];
        DHCP = "no";
        IPv6AcceptRA = false;
      };
    };
  };
}
