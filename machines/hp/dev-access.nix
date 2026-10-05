# Test phase only: tooling and remote access for developing on the hp dom0.
# Root SSH with password is insecure; it is limited to the home LAN.
# Set the root password imperatively with `sudo passwd root`.
{ pkgs, ... }:
let
  lan = "192.168.178.0/24";
in
{
  environment.systemPackages = with pkgs; [
    claude-code
    google-chrome
  ];

  # Dedicated key from xmg (~/.ssh/hp), so login does not depend on passwords
  users.users.nx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAffatqEOWD3PYvo5A4SOzoBnMGSRttSoONnh9ooylhD hp-dom0"
  ];

  services.openssh = {
    enable = true;
    # Port 22 is opened for the LAN only (see firewall below)
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    extraConfig = ''
      Match Address ${lan}
        PermitRootLogin yes
        PasswordAuthentication yes
    '';
  };

  networking.firewall = {
    extraCommands = ''
      iptables -A nixos-fw -p tcp -s ${lan} --dport 22 -j nixos-fw-accept
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -p tcp -s ${lan} --dport 22 -j nixos-fw-accept || true
    '';
  };
}
