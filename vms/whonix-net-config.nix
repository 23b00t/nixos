# filepath: vms/whonix-net-config.nix
{
  index,
  lib,
  ...
}:
let
  id = toString index;
  # Calculates MAC suffix (Hex)
  hexId = lib.toHexString index;
  hexTorId = lib.toHexString (index + 1);
  
  # Calculates IP suffix for Tor network
  torIpSuffix = toString (10 + index);
in
{
  networking.useNetworkd = true;

  # Interface 1: SSH (connected to vm-irc-ssh on host)
  systemd.network.networks."10-ssh" = {
    # Matches the MAC defined in flake.nix (e.g. ...0b)
    matchConfig.MACAddress = "02:00:00:00:00:0${hexId}";
    # Host route points to 10.0.0.11
    address = [ "10.0.0.${id}/32" ];
    routes = [
      # Route back to host (Host has 10.0.0.0 on this link)
      {
        Destination = "10.0.0.0/32";
        Scope = "link";
      }
    ];
  };

  # Interface 2: Whonix (connected to vm-irc-tor on host)
  systemd.network.networks."20-tor" = {
    # Matches the MAC defined in flake.nix (e.g. ...0c)
    matchConfig.MACAddress = "02:00:00:00:00:0${hexTorId}";
    address = [ "10.152.152.${torIpSuffix}/18" ]; # IP in Whonix subnet
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "10.152.152.10"; # Whonix Gateway
      }
    ];
    # SECURITY: DNS only via Whonix
    networkConfig.DNS = [ "10.152.152.10" ];
  };
}
