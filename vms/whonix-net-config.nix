# filepath: vms/whonix-net-config.nix
{ lib, index, ... }:
let
  id = toString index;
  # Berechnet MAC Endung für Tor Interface (Index + 1)
  # Achtung: Funktioniert hier nur für einstellige Indizes sauber, für >9 müsste man hex umrechnen
  torId = toString (index + 1);
in
{
  networking.useNetworkd = true;
  
  # Interface 1: SSH (verbunden mit vm-irc-ssh am Host)
  systemd.network.networks."10-ssh" = {
    # Matcht auf die in flake.nix definierte MAC (02:...:05)
    matchConfig.MACAddress = "02:00:00:00:00:0${id}";
    # Host Route zeigt auf 10.0.0.5, also muss die VM diese IP haben
    address = [ "10.0.0.${id}/32" ]; 
    routes = [
      # Route zurück zum Host (Host hat 10.0.0.0 auf diesem Link)
      { Destination = "10.0.0.0/32"; Scope = "link"; }
    ];
  };

  # Interface 2: Whonix (verbunden mit vm-irc-tor am Host)
  systemd.network.networks."20-tor" = {
    # Matcht auf die in flake.nix definierte MAC (02:...:06)
    matchConfig.MACAddress = "02:00:00:00:00:0${torId}";
    address = [ "10.152.152.12/18" ]; # IP im Whonix Subnetz
    routes = [{
      Destination = "0.0.0.0/0";
      Gateway = "10.152.152.10"; # Whonix Gateway
    }];
    # SICHERHEIT: DNS nur über Whonix
    networkConfig.DNS = [ "10.152.152.10" ]; 
  };
}
