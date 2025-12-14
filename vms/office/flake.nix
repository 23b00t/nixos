{
  description = "Office MicroVM";

  inputs = {
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flatpaks = {
      url = "github:in-a-dil-emma/declarative-flatpak/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
      flatpaks,
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
            flatpaks.nixosModules.default
            (
              { config, pkgs, ... }:
              # INFO: build termusic with mpv support to work with pulse and not enforce alsa
              let
                termusic-mpv = pkgs.termusic.overrideAttrs (old: {
                  cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features=mpv" ];
                  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
                  buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.mpv ];
                });
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "office-vm";

                users.groups.users = { };
                users.users.user = {
                  password = "trash";
                  isNormalUser = true;
                  group = "users";
                  extraGroups = [ "wheel" ];
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC76Fb5xSeNdZ9BVPf7OdLWhULXgb1OCAgPfYoeLZBl office-vm"
                  ];
                  linger = true;
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = false;
                  };
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
                      size = 1028;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 2048;
                    }
                    {
                      mountPoint = "/var/lib/flatpak";
                      image = "flatpak.img";
                      size = 6000;
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
                  vcpu = 6;
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

                environment.variables = {
                  PULSE_SERVER = "tcp:localhost:4713";
                };

                # Flatpak settings
                # Enable XDG portal for Flatpak apps

                xdg.portal = {
                  enable = true;

                  extraPortals = [
                    pkgs.xdg-desktop-portal-xapp
                    pkgs.xdg-desktop-portal-gtk
                  ];

                  config.common = {
                    default = "xapp";
                    "org.freedesktop.portal.FileChooser" = "xapp";
                  };
                };

                services.flatpak = {
                  enable = true;
                  flatpakDir = "/var/lib/flatpak";
                  remotes = {
                    "flathub" = "https://dl.flathub.org/repo/flathub.flatpakrepo";
                    "flathub-beta" = "https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo";
                  };
                  packages = [
                    "flathub:app/org.onlyoffice.desktopeditors/x86_64/stable"
                  ];
                  overrides = {
                    # "org.onlyoffice.desktopeditors" = {
                    #   Context = {
                    #     sockets = [
                    #       "x11"
                    #       "pulseaudio"
                    #       "!wayland"
                    #     ];
                    #     filesystems = [ "host" ];
                    #   };
                    #   Environment = {
                    #     "QT_QPA_PLATFORM" = "xcb";
                    #     "QT_QUICK_BACKEND" = "software";
                    #     "QT_GRAPHICSSYSTEM" = "software";
                    #   };
                    # };
                    "org.onlyoffice.desktopeditors" = {
                      Context = {
                        sockets = [
                          "wayland"
                          "pulseaudio"
                          "!x11"
                        ];
                        filesystems = [ "host" ];
                      };
                      Environment = {
                        "QT_QPA_PLATFORM" = "wayland";
                        "GDK_BACKEND" = "wayland";
                      };
                    };
                  };
                };

                environment.systemPackages = with pkgs; [
                  # INFO: set in .config/termusic/server.toml:
                  # [player]
                  # backend = "mpv"
                  # [backends.mpv]
                  # audio_device = "pulse"
                  termusic-mpv
                  # pulseaudio
                  # mpv
                  yt-dlp
                  # onlyoffice-desktopeditors
                  gimp
                  inkscape
                  vlc
                  pinta
                  pdfarranger
                  wine

                  adwaita-icon-theme
                  wprs
                  xwayland

                  (import ./vm-connect.nix { inherit pkgs; })
                ];

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
