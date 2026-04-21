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
      index = 9;
      mac = "00:00:00:00:00:09";
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
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC76Fb5xSeNdZ9BVPf7OdLWhULXgb1OCAgPfYoeLZBl office-vm";
            })
            ../modules/yazi-config.nix
            (import ../rdp.nix { inherit lib; })
            (
              { config, pkgs, ... }:
              let
                printer = import ./printer.nix { inherit pkgs; };
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "office-vm";

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  optimize.enable = false;
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

                systemd.user.services.wprsd = {
                  description = "wprsd instance";
                  after = [ "network.target" ];
                  serviceConfig = {
                    Type = "simple";
                    Environment = [
                      "PATH=/run/current-system/sw/bin"
                      "RUST_BACKTRACE=1"
                    ];
                    ExecStart = "/run/current-system/sw/bin/wprsd";
                  };
                  wantedBy = [ "default.target" ];
                };

                # Setup xrdp with fluxbox
                services.xrdp = {
                  defaultWindowManager = ''
                    exec fluxbox -no-toolbar &
                    fbpid=$!
                    sleep 2
                    setxkbmap -layout "us" -variant "intl" -option "grp:alt_shift_toggle"
                    onlyoffice-desktopeditors &
                    wait $fbpid
                  '';
                };

                services.printing.enable = true;

                systemd.services.host-printer-tunnel = {
                  description = "SSH Tunnel to Host CUPS";
                  after = [ "network-online.target" ];
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = "${printer.hostPrinterTunnelScript}/bin/host-printer-tunnel";
                    Restart = "on-failure";
                    RestartSec = 5;
                  };
                };
                systemd.services.add-host-printers = {
                  description = "Add all host CUPS printers via SSH tunnel";
                  after = [ "host-printer-tunnel.service" ];
                  requires = [ "host-printer-tunnel.service" ];
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                  };
                  script = "${printer.hostPrintersAddScript}/bin/host-printers-add";
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    onlyoffice-desktopeditors
                    gimp
                    inkscape
                    vlc
                    pinta
                    pdfarranger

                    adwaita-icon-theme
                    wprs
                    xwayland
                    kitty

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
                  ]
                  ++ defaultPkgs;

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
