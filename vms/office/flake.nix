{
  description = "Office MicroVM";

  inputs = {
    microvm = {
      url = "github:astro/microvm.nix";
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
            (import ../yazi-config.nix { inherit pkgs; })
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

                  writableStoreOverlay = "/nix/.rw-store";
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
                    {
                      mountPoint = "/var/log";
                      image = "log.img";
                      size = 1028;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 2048;
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
#               systemd.services.host-printer-tunnel = {
#                 description = "SSH Tunnel to Host CUPS";
#                 after = [ "network-online.target" ]; # Wartet auf eine aktive Netzwerkverbindung
#                 wantedBy = [ "multi-user.target" ];

#                 # Schritt 2: Der Service ruft jetzt nur noch das saubere Skript auf.
#                 serviceConfig = {
#                   Type = "simple";
#                   ExecStart = "${printer.hostPrinterTunnelScript}/bin/host-printer-tunnel";
#                   Restart = "on-failure";
#                   RestartSec = 5;
#                 };
#               };

#               systemd.services.add-host-printer = {
#                 description = "Add CUPS printer via SSH tunnel";
#                 after = [ "host-printer-tunnel.service" ]; # Startet erst nach dem Tunnel-Service
#                 requires = [ "host-printer-tunnel.service" ];
#                 wantedBy = [ "multi-user.target" ];
#                 serviceConfig = {
#                   Type = "oneshot"; # Läuft nur einmal
#                   RemainAfterExit = true; # Bleibt als "erfolgreich" markiert
#                 };
#                 script = ''
#                   LP_NAME="HostPrinter"
#                   PRINTER_NAME="HP_LaserJet_M110w_42FA89"
#                   TUNNEL_PORT=1631

#                   # Warten, bis der Tunnel-Port wirklich offen ist
#                   while ! ${pkgs.lsof}/bin/lsof -i TCP:''${TUNNEL_PORT} >/dev/null 2>&1; do
#                       echo "Waiting for tunnel on port ''${TUNNEL_PORT}..."
#                       sleep 1
#                   done

#                   if ! ${pkgs.cups}/bin/lpstat -p | ${pkgs.gnugrep}/bin/grep -q "^printer ''${LP_NAME} "; then
#                       echo "Adding printer ''${LP_NAME}..."
#                       ${pkgs.cups}/bin/lpadmin -p ''${LP_NAME} -E -v ipp://localhost:''${TUNNEL_PORT}/printers/''${PRINTER_NAME} -m everywhere
#                   fi
#                 '';
#               };

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

                    dconf # to fix onlyoffice errors

                    (import ../copy-between-vms.nix { inherit pkgs; })
                  ]
                  ++ defaultPkgs;

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
