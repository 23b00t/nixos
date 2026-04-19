{
  description = "Chat MicroVM";

  inputs = {
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flatpaks = {
      url = "github:in-a-dil-emma/declarative-flatpak/latest";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
      flatpaks,
      ...
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
      index = 2;
      mac = "00:00:00:00:00:02";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.chat;
        chat = self.nixosConfigurations.chat.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        chat = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            flatpaks.nixosModules.default
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqGdw377nJ+Zcf2kXwIiXPi5OFuY5KPOuhi0YaWhGmb chat-vm";
            })
            (import ../rdp.nix { inherit lib; })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "chat-vm";

                # Flatpak settings
                # Enable XDG portal for Flatpak apps
                xdg.portal.enable = true;
                xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
                xdg.portal.config.common.default = "gtk";
                services.flatpak = {
                  enable = true;
                  flatpakDir = "/var/lib/flatpak";
                  remotes = {
                    "flathub" = "https://dl.flathub.org/repo/flathub.flatpakrepo";
                    "flathub-beta" = "https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo";
                  };
                  packages = [
                    "flathub:app/us.zoom.Zoom/x86_64/stable"
                  ];
                };

                microvm = {
                  registerClosure = false;
                  hypervisor = "qemu";
                  optimize.enable = false;
                  # qemu.machine = "q35";

                  qemu.extraArgs = [
                    "-nodefaults"
                    "-device"
                    "usb-ehci,id=ehci"
                    "-device"
                    "usb-host,bus=ehci.0,vendorid=0x2b7e,productid=0xc906,guest-reset=false,pipeline=false"
                  ];

                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 4096;
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
                  ];
                  # devices = [
                  #   {
                  #     bus = "usb";
                  #     path = "vendorid=0x0408,productid=0x5365,guest-reset=false,pipeline=false";
                  #   }
                  # ];
                  mem = 8192;
                  vcpu = 4;
                };

                services.xrdp = {
                  defaultWindowManager = ''
                    exec fluxbox -no-toolbar &
                    fbpid=$!
                    sleep 2
                    setxkbmap -layout "us" -variant "intl" -option "grp:alt_shift_toggle"
                    kitty &
                    wait $fbpid
                  '';
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

                environment.systemPackages =
                  with pkgs;
                  [
                    vesktop
                    telegram-desktop
                    slack
                    google-chrome
                    wprs
                    xwayland

                    mesa
                    vulkan-loader

                    kitty


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
