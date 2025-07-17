{
  description = "NixOS in MicroVMs";

   inputs.microvm = {
     url = "github:astro/microvm.nix";
     inputs.nixpkgs.follows = "nixpkgs";
   };

  outputs = { self, nixpkgs, microvm }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      lib = nixpkgs.lib;
      index = 1;
      mac = "00:00:00:00:00:01";
    in {
      packages.${system} = {
        default = self.packages.${system}.net-vm;
        net-vm = self.nixosConfigurations.net-vm.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        net-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ({ config, ... }: {
              networking.hostName = "net-vm";

              microvm = {
                writableStoreOverlay = "/nix/.rw-store";
                hypervisor = "cloud-hypervisor";
                interfaces = [{
                  id = "vm${toString index}";
                  type = "tap";
                  inherit mac;
                }];
                volumes = [
                  { 
                    mountPoint = "/var";
                    image = "var.img";
                    size = 8192;
                  }
                  { 
                    mountPoint = "/home/nx";
                    image = "home.img";
                    size = 8192;
                  }
                  {
                    image = "nix-store-overlay.img";
                    mountPoint = config.microvm.writableStoreOverlay;
                    size = 8192;
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
                mem = 4096;
              };
              boot.initrd.postDeviceCommands = lib.mkForce "";
              # system.stateVersion = lib.trivial.release;
              system.stateVersion = "25.05";

              services.getty.autologinUser = "nx";
              users.users.nx = {
                password = "trash";
                group = "nx";
                isNormalUser = true;
                extraGroups = [ "wheel" "video" ];

                openssh.authorizedKeys.keys = [ 
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINB4DnXkH9Y/XWof2jgTkrdCrc7X9OtlxQI69L8U81P9 nx@machine"
                ];
              };
              users.groups.nx = {};
              security.sudo = {
                enable = true;
                wheelNeedsPassword = false;
              };

              systemd.tmpfiles.rules = [
                "d /home/nx 0700 nx nx -"
              ];

              environment.systemPackages = with pkgs; [
                waypipe
                firefox
                discord
                zoom-us
                # telegram-desktop
                qmmp
              ];

              # xdg.portal = {
              #   enable = true;
              #   extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
              #   config.common.default = "*";
                # Optional: spezifisch Wayland-Integration
                # extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-wlr ];
              # };
              # services.flatpak.enable = true;

              hardware.graphics.enable = true;

              networking.useNetworkd = true;

              # ssh for waypipe
              services.openssh = {
                enable = true;
                settings = {
                  PasswordAuthentication = false;
                  PubkeyAuthentication = true;
                  PermitRootLogin = "no";
                };
              };
              
              # Audio in der MicroVM
              services.pulseaudio.enable = false;
              services.pipewire = {
                enable = true;
                pulse.enable = true;
                alsa.enable = true;
                alsa.support32Bit = true;
                jack.enable = true;
              };

              # Umgebungsvariable für alle User
              environment.sessionVariables = {
                PULSE_SERVER = "tcp:localhost:4713";
                # Für Wayland-Support
                QT_QPA_PLATFORM = "wayland;xcb";
                GDK_BACKEND = "wayland,x11";
                NIXOS_OZONE_WL = "1";  # Für Electron-Apps wie Discord
                MOZ_ENABLE_WAYLAND = "1";
                XDG_SESSION_TYPE = "wayland";
                DISPLAY = ":0";
                SDL_VIDEODRIVER = "wayland";
                CLUTTER_BACKEND = "wayland";
              };

              systemd.network.networks."10-eth" = {
                matchConfig.MACAddress = mac;
                address = [
                  "10.0.0.${toString index}/32"
                  "fec0::${lib.toHexString index}/128"
                ];
                routes = [
                  { Destination = "10.0.0.0/32"; GatewayOnLink = true; }
                  { Destination = "0.0.0.0/0"; Gateway = "10.0.0.0"; GatewayOnLink = true; }
                  { Destination = "::/0"; Gateway = "fec0::"; GatewayOnLink = true; }
                ];
                networkConfig = {
                  DNS = [
                    "9.9.9.9"
                    "149.112.112.112"
                    "2620:fe::fe"
                    "2620:fe::9"
                  ];
                };
              };
            }
            )
          ];
        };
      };
    };
}
