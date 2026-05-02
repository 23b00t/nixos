{
  description = "Office MicroVM";

  inputs = {
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        default = self.packages.${system}.office;
        office = self.nixosConfigurations.office.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        office = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/common-config.nix
            ../modules/yazi-config.nix
            ../modules/wprs.nix
            (
              { config, pkgs, ... }:
              let
                printer = import ./printer.nix { inherit pkgs; };
              in
              {
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
                  registerClosure = false;
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

                systemd.services.print-gateway-tunnel = {
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
                systemd.services.add-print-gateway-printers = {
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

                  # DEBUG: wprs 10.0.0.9 run -- env QT_DEBUG_PLUGINS=1 GTK_DEBUG=all XDG_RUNTIME_DIR=/run/user/1000 onlyoffice-desktopeditors --native-file-dialog
                  # Provoke crash: wprs 10.0.0.9 run -- env -u DBUS_SESSION_BUS_ADDRESS -u XDG_CURRENT_DESKTOP -u XDG_SESSION_TYPE onlyoffice-desktopeditors --native-file-dialog
                  # gtk3
                  # qt5.qtbase
                  # qt5.qttools
                  # qt5.qtsvg
                  # qt5.qtwayland
                  # mesa
                  # libGL
                  # gedit

                  dconf # to fix onlyoffice errors
                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
