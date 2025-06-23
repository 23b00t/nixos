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
                socket = "control.socket";
                graphics.enable = true;
                interfaces = [{
                  id = "vm${toString index}";
                  type = "tap";
                  inherit mac;
                }];
                volumes = [
                  { 
                    mountPoint = "/var";
                    image = "var.img";
                    size = 256;
                  }
                ];

                shares = [ 
                  {
                    # use proto = "virtiofs" for MicroVMs that are started by systemd
                    proto = "9p";
                    tag = "ro-store";
                    # a host's /nix/store will be picked up so that no
                    # squashfs/erofs will be built for it.
                    source = "/nix/store";
                    mountPoint = "/nix/.ro-store";
                  } 
                  {
                    proto      = "9p";
                    tag        = "wayland";
                    source     = "/run/user/1000";
                    mountPoint = "/wayland-host";
                  }
                ];
              };

              system.stateVersion = lib.trivial.release;

              services.getty.autologinUser = "nx";
              users.users.nx = {
                password = "";
                group = "nx";
                isNormalUser = true;
                extraGroups = [ "wheel" "video" ];
              };
              users.groups.nx = {};
              security.sudo = {
                enable = true;
                wheelNeedsPassword = false;
              };

              environment.sessionVariables = {
                WAYLAND_DISPLAY = "/wayland-host/wayland-1";
                # WAYLAND_DISPLAY = "tcp:10.0.2.2:12345";
                # WAYLAND_DISPLAY = "wayland-1";
                DISPLAY = ":0";
              };

              environment.systemPackages = with pkgs; [
                xdg-utils
                firefox
                wayland-proxy-virtwl
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
