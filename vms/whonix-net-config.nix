{ index, mac, ... }:

{
  microvm.interfaces = [{
    id = "vm${toString index}";
    type = "tap";
    inherit mac;
  }];

  networking.useNetworkd = true;

  systemd.network.networks."10-eth" = {
    matchConfig.MACAddress = mac;
    address = [
      "10.0.2.15/24"  # IP im Whonix External Network
    ];
    routes = [{
      Destination = "0.0.0.0/0";
      Gateway = "10.0.2.2";  # Whonix Gateway über virbr1
    }];
    networkConfig.DNS = [
      "10.0.2.2"  # DNS über Whonix
    ];
  };
}
