{
  description = "net vm with systemd service";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microvm }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    (import ./vm-networking.nix {
      inherit lib;
      index = 5;
      mac = "00:00:00:00:00:01";
    })
    packages.${system} = {
      default = self.packages.${system}.net-vm;
      net-vm = self.nixosConfigurations.net-vm.config.microvm.declaredRunner;
    };
    nixosConfigurations.net-vm = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        {
        environment.systemPackages = with pkgs; [
          firefox
          vim
        ];
        }
        microvm.nixosModules.microvm
        {
          # networking.useDHCP = false;
          # networking.interfaces.enp0s4.ipv4.addresses = [{
            # address = "192.168.100.2";
            # prefixLength = 24;
          # }];
          # networking.defaultGateway.address = "192.168.100.1";
          # networking.defaultGateway.interface = "enp0s4";
          # networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

          users.users.root.password = "";

          microvm = {
            volumes = [{
              mountPoint = "/var";
              image = "var.img";
              size = 256;
            }];

            shares = [{
              proto = "9p";
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
            }];

            interfaces = [{
              type = "tap";
              id = "vm-net";
              mac = "02:00:00:00:00:01";
            }];

            hypervisor = "qemu";
            socket = "control.socket";
          };
        }
      ];
    };
  };
}
