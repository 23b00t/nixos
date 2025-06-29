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
      index = 2;
      mac = "00:00:00:00:00:02";
    in {
      packages.${system} = {
        default = self.packages.${system}.net-vm-qemu;
        net-vm-qemu = self.nixosConfigurations.net-vm-qemu.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        net-vm-qemu = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            {
              networking.hostName = "net-vm-qemu";

              microvm = {
                hypervisor = "qemu";
                socket = "control.socket";
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
                    proto = "9p";
                    tag = "ro-store";
                    source = "/nix/store";
                    mountPoint = "/nix/.ro-store";
                  } 
                ];
                mem = 2096;
              };
              system.stateVersion = lib.trivial.release;

              hardware.graphics.enable = true;

              services.getty.autologinUser = "nx";
              users.users.nx = {
                password = "trash";
                group = "nx";
                isNormalUser = true;
                extraGroups = [ "wheel" "video" ];
              };
              users.groups.nx = {};
              security.sudo = {
                enable = true;
                wheelNeedsPassword = false;
              };

              environment.systemPackages = with pkgs; [
                firefox
                neverball
                waypipe
              ];
                            
              networking.useNetworkd = true;

              # ssh for waypipe
              services.openssh = {
                enable = true;
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
          ];
        };
      };
    };
}
