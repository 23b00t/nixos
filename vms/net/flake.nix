{
  description = "NixOS in MicroVMs";

  inputs.microvm = {
    url = "github:astro/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, microvm }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
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
            {
              networking.hostName = "net-vm";
              # users.users.root.password = "";

              microvm = {
                hypervisor = "qemu";
                graphics.enable = true;
                interfaces = [{
                  id = "vm${toString index}";
                  type = "tap";
                  inherit mac;
                }];
              };

              system.stateVersion = lib.trivial.release;

              services.getty.autologinUser = "user";
              users.users.user = {
                password = "";
                group = "user";
                isNormalUser = true;
                extraGroups = [ "wheel" "video" ];
              };
              users.groups.user = {};
              security.sudo = {
                enable = true;
                wheelNeedsPassword = false;
              };

              environment.sessionVariables = {
                WAYLAND_DISPLAY = "wayland-1";
                DISPLAY = ":0";
                QT_QPA_PLATFORM = "wayland"; # Qt Applications
                GDK_BACKEND = "wayland"; # GTK Applications
                XDG_SESSION_TYPE = "wayland"; # Electron Applications
                SDL_VIDEODRIVER = "wayland";
                CLUTTER_BACKEND = "wayland";
              };

              systemd.user.services.wayland-proxy = {
                enable = true;
                description = "Wayland Proxy";
                serviceConfig = with pkgs; {
                  # Environment = "WAYLAND_DISPLAY=wayland-1";
                  ExecStart = "${wayland-proxy-virtwl}/bin/wayland-proxy-virtwl --virtio-gpu --x-display=0 --xwayland-binary=${xwayland}/bin/Xwayland";
                  Restart = "on-failure";
                  RestartSec = 5;
                };
                wantedBy = [ "default.target" ];
              };

              environment.systemPackages = with pkgs; [
                xdg-utils # Required
                firefox
              ];

              hardware.graphics.enable = true;

              networking.useNetworkd = true;

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
          ];
        };
      };
    };
}
