# Whonix Workstation Network Configuration
{ lib, index, mac, ... }:

{
  microvm.interfaces = [{
    id = "vm${toString index}";
    type = "tap";
    inherit mac;
  }];

  networking.useNetworkd = true;
  services.openssh.enable = true;

  systemd.network.networks."11-eth" = {
    matchConfig.MACAddress = mac;
    # Static IP configuration for Whonix Workstation
    address = [
      "10.152.152.${toString (10 + index)}/18"  # netmask: 255.255.192.0
    ];
    routes = [{
      # Default route via Whonix Gateway
      Destination = "0.0.0.0/0";
      Gateway = "10.152.152.10";
    }];
    networkConfig.DNS = [
      "9.9.9.9"
      "149.112.112.112"
      "2620:fe::fe"
      "2620:fe::9"
    ];
  };
}
