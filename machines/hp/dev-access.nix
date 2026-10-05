# Test phase only: tooling and remote access for developing on the hp dom0.
# SSH is key-only (nx) and limited to the home LAN.
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

  # Lets Claude run the Xen test plan and apply fixes without a password.
  # xl and nixos-rebuild are root-equivalent anyway; boot/reboot stay manual.
  security.sudo.extraRules = [
    {
      users = [ "nx" ];
      commands =
        map
          (command: {
            inherit command;
            options = [ "NOPASSWD" ];
          })
          (
            [
              "/run/current-system/sw/bin/xl *"
              "/run/current-system/sw/bin/nixos-rebuild switch *"
            ]
            ++ map (verb: "/run/current-system/sw/bin/systemctl ${verb} microvm@*") [
              "start"
              "stop"
              "restart"
              "kill *"
            ]
            ++ [ "/run/current-system/sw/bin/systemctl restart home-manager-nx" ]
          );
    }
  ];

  services.openssh = {
    enable = true;
    # Port 22 is opened for the LAN only (see firewall below)
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
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
