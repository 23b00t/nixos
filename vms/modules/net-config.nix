{ lib, config, ... }:

with lib;

let
  cfg = config.services.net-config;
in
{
  options.services.net-config = {
    enable = mkEnableOption "Enable the VM network configuration module";
    index = mkOption {
      type = types.int;
      description = "VM index for IP addressing";
    };
    mac = mkOption {
      type = types.str;
      description = "MAC address for the VM interface";
    };
  };

  config = mkIf cfg.enable {
    microvm.interfaces = [
      {
        id = "vm${toString cfg.index}";
        type = "tap";
        mac = cfg.mac;
      }
    ];

    networking.useNetworkd = true;
    services.openssh.enable = true;

    systemd.network.networks."10-eth" = {
      matchConfig.MACAddress = cfg.mac;
      address = [
        "10.0.0.${toString cfg.index}/32"
        "fec0::${lib.toHexString cfg.index}/128"
      ];
      routes = [
        {
          Destination = "10.0.0.254/32";
          GatewayOnLink = true;
        }
        {
          Destination = "fec0::ff/128";
          GatewayOnLink = true;
        }
        {
          Destination = "0.0.0.0/0";
          Gateway = "10.0.0.0";
          GatewayOnLink = true;
        }
        {
          Destination = "::/0";
          Gateway = "fec0::";
          GatewayOnLink = true;
        }
      ];
      networkConfig.DNS = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
        "2620:fe::9"
      ];
    };
  };
}
