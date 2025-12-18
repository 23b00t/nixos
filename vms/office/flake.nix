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
      index = 3;
      mac = "00:00:00:00:00:03";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.office;
        chat = self.nixosConfigurations.office.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        office = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC76Fb5xSeNdZ9BVPf7OdLWhULXgb1OCAgPfYoeLZBl office-vm";
            })
            (
              { config, pkgs, ... }:
              # INFO: build termusic with mpv support to work with pulse and not enforce alsa
              let
                termusic-mpv = pkgs.termusic.overrideAttrs (old: {
                  cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features=mpv" ];
                  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
                  buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.mpv ];
                });

                printer = import ./printer.nix { inherit pkgs; };
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "office-vm";

                users.users.user = {
                  linger = true;
                  extraGroups = lib.mkAfter [ "video" ];
                };

                microvm = {
                  registerClosure = false;
                  # vsock.cid = 3;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 2048;
                    }
                    {
                      mountPoint = "/root";
                      image = "root.img";
                      size = 128;
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
                    {
                      proto = "virtiofs";
                      tag = "host-home";
                      source = "/home/nx";
                      mountPoint = "/mnt/host";
                    }
                  ];
                  mem = 6144;
                  vcpu = 2;
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

                # For termusic
                environment.variables = {
                  PULSE_SERVER = "tcp:localhost:4713";
                };

                # NOTE: Hyprland experiment (no success yet, no rdp server running)
                # grdctl --headless needs to be setup completly
                # programs.hyprland.enable = true;
                # services.greetd.enable = true;
                # services.greetd.settings.default_session = {
                #   command = "${pkgs.hyprland}/bin/Hyprland";
                #   user = "user";
                # };
                # services.gnome.gnome-remote-desktop.enable = true;
                # systemd.services.gnome-remote-desktop = {
                #   wantedBy = [ "graphical.target" ];
                # };
                # services.gnome.gnome-keyring.enable = true;
                # services.dbus.enable = true;

                # NOTE: Working Xfce4 + xrdp setup
                # services.xrdp.enable = true;
                # services.xrdp.defaultWindowManager = "xfce4-session";
                # services.xserver.enable = true;
                # services.xserver.displayManager.lightdm.enable = true;
                # services.xserver.desktopManager.xfce.enable = true;

                # Setup xrdp with fluxbox
                networking.firewall = {
                  allowedTCPPorts = [ 3389 ];
                  allowedUDPPorts = [ 3389 ];
                };
                services.xrdp = {
                  enable = true;
                  audio.enable = true;
                  defaultWindowManager = ''
                    exec fluxbox -no-toolbar &
                    fbpid=$!
                    sleep 2
                    setxkbmap -layout "us" -variant "intl" -option "grp:alt_shift_toggle"
                    onlyoffice-desktopeditors &
                    wait $fbpid
                  '';
                };
                services.xserver.enable = true;
                services.xserver.windowManager.fluxbox.enable = true;

                services.printing.enable = true;
                systemd.services.host-printer-tunnel = {
                  description = "SSH Tunnel to Host CUPS";
                  after = [ "network-online.target" ]; # Wartet auf eine aktive Netzwerkverbindung
                  wantedBy = [ "multi-user.target" ];

                  # Schritt 2: Der Service ruft jetzt nur noch das saubere Skript auf.
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = "${printer.hostPrinterTunnelScript}/bin/host-printer-tunnel";
                    Restart = "on-failure";
                    RestartSec = 5;
                  };
                };

                systemd.services.add-host-printer = {
                  description = "Add CUPS printer via SSH tunnel";
                  after = [ "host-printer-tunnel.service" ]; # Startet erst nach dem Tunnel-Service
                  requires = [ "host-printer-tunnel.service" ];
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig = {
                    Type = "oneshot"; # Läuft nur einmal
                    RemainAfterExit = true; # Bleibt als "erfolgreich" markiert
                  };
                  script = ''
                    LP_NAME="HostPrinter"
                    PRINTER_NAME="HP_LaserJet_M110w_42FA89"
                    TUNNEL_PORT=1631

                    # Warten, bis der Tunnel-Port wirklich offen ist
                    while ! ${pkgs.lsof}/bin/lsof -i TCP:''${TUNNEL_PORT} >/dev/null 2>&1; do
                        echo "Waiting for tunnel on port ''${TUNNEL_PORT}..."
                        sleep 1
                    done

                    if ! ${pkgs.cups}/bin/lpstat -p | ${pkgs.gnugrep}/bin/grep -q "^printer ''${LP_NAME} "; then
                        echo "Adding printer ''${LP_NAME}..."
                        ${pkgs.cups}/bin/lpadmin -p ''${LP_NAME} -E -v ipp://localhost:''${TUNNEL_PORT}/printers/''${PRINTER_NAME} -m everywhere
                    fi
                  '';
                };

                environment.etc."ssh_config".text = ''
                  Host *
                      StrictHostKeyChecking no
                      UserKnownHostsFile /dev/null
                '';
                systemd.tmpfiles.rules = [
                  "L+ /home/user/.ssh/config - - - - /etc/ssh_config"
                ];

                environment.systemPackages =
                  with pkgs;
                  [
                    # INFO: set in .config/termusic/server.toml:
                    # [player]
                    # backend = "mpv"
                    # [backends.mpv]
                    # audio_device = "pulse"
                    termusic-mpv
                    # pulseaudio
                    # mpv
                    yt-dlp
                    onlyoffice-desktopeditors
                    gimp
                    inkscape
                    vlc
                    pinta
                    pdfarranger
                    wine

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
