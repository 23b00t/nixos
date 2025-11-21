# filepath: vms/whonix-net-config.nix
{ index, ... }:
let
  id = toString index;
  # Calculates MAC suffix for Tor interface (Index + 1)
  # Note: Only works cleanly for single-digit indices, hex conversion needed for >9
  torId = toString (index + 1);
  # Calculates IP suffix for Tor network (Gateway is .10, so we start at .10 + index)
  # Example: Index 5 -> 10.152.152.15
  torIpSuffix = toString (10 + index);
in
{
  networking.useNetworkd = true;
  
  # Interface 1: SSH (connected to vm-irc-ssh on host)
  systemd.network.networks."10-ssh" = {
    # Matches the MAC defined in flake.nix (02:...:05)
    matchConfig.MACAddress = "02:00:00:00:00:0${id}";
    # Host route points to 10.0.0.5, so the VM must have this IP
    address = [ "10.0.0.${id}/32" ]; 
    routes = [
      # Route back to host (Host has 10.0.0.0 on this link)
      { Destination = "10.0.0.0/32"; Scope = "link"; }
    ];
  };

  # Interface 2: Whonix (connected to vm-irc-tor on host)
  systemd.network.networks."20-tor" = {
    # Matches the MAC defined in flake.nix (02:...:06)
    matchConfig.MACAddress = "02:00:00:00:00:0${torId}";
    address = [ "10.152.152.${torIpSuffix}/18" ]; # IP in Whonix subnet
    routes = [{
      Destination = "0.0.0.0/0";
      Gateway = "10.152.152.10"; # Whonix Gateway
    }];
    # SECURITY: DNS only via Whonix
    networkConfig.DNS = [ "10.152.152.10" ]; 
  };
}
