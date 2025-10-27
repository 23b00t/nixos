# vm-networking.nix
{ lib, index, mac, ... }:

{
  microvm.interfaces = [{
    id = "vm${toString index}";
    type = "tap";
    inherit mac;
  }];

  networking.useNetworkd = true;
  services.openssh.enable = true;

  systemd.network.networks."10-eth" = {
    matchConfig.MACAddress = mac;
    address = [
      "10.0.0.${toString index}/32"
      "fec0::${lib.toHexString index}/128"
    ];
    routes = [{
      Destination = "10.0.0.0/32";
      GatewayOnLink = true;
    } {
      Destination = "0.0.0.0/0";
      Gateway = "10.0.0.0";
      GatewayOnLink = true;
    } {
      Destination = "::/0";
      Gateway = "fec0::";
      GatewayOnLink = true;
    }];
    networkConfig.DNS = [
      "9.9.9.9"
      "149.112.112.112"
      "2620:fe::fe"
      "2620:fe::9"
    ];
  };
}
