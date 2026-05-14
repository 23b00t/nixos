{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/yazi-config.nix
    ../modules/wprs.nix
  ];

  nixpkgs.config.allowUnfree = true;
  networking.hostName = "office-vm";

  services.net-config = {
    enable = true;
    index = 9;
    mac = "00:00:00:00:00:09";
  };

  services.common-config = {
    enable = true;
  };

  microvm = {
    vsock.cid = 11;
    hypervisor = "cloud-hypervisor";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 20000;
      }
      {
        mountPoint = "/root";
        image = "root.img";
        size = 256;
      }
    ];
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    mem = 6144;
    vcpu = 4;
  };

  services.printing.enable = true;

  systemd.services.print-gateway-tunnel =
    let
      printer = import ./printer.nix { inherit pkgs; };
    in
    {
      description = "SSH Tunnel to sys-net CUPS";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${printer.printGatewayTunnelScript}/bin/print-gateway-tunnel";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

  systemd.services.add-print-gateway-printers =
    let
      printer = import ./printer.nix { inherit pkgs; };
    in
    {
      description = "Add all sys-net CUPS printers via SSH tunnel";
      after = [ "print-gateway-tunnel.service" ];
      requires = [ "print-gateway-tunnel.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "${printer.printGatewayPrintersAddScript}/bin/print-gateway-printers-add";
    };

  environment.systemPackages = with pkgs; [
    onlyoffice-desktopeditors
    libreoffice
    gimp
    inkscape
    vlc
    pinta
    pdfarranger
    adwaita-icon-theme
    dconf
  ];

  system.stateVersion = "26.05";
}
