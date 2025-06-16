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
    nixosConfigurations.net-vm = pkgs.lib.nixosSystem {
      inherit system;
      modules = [
        microvm.nixosModules.microvm
        {
          networking.useDHCP = false;
          networking.interfaces.enp0s1.ipv4.addresses = [{
            address = "192.168.100.2";
            prefixLength = 24;
          }];
          networking.defaultGateway.address = "192.168.100.1";
          networking.defaultGateway.interface = "enp0s1";
          networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

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

          # Systemd service to start VM manually and set up tap + NAT
          systemd.services.microvm-net-vm = {
            description = "Start MicroVM net-vm with tap networking";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStartPre = ''
                ${pkgs.iproute2}/bin/ip tuntap add dev vm-net mode tap user ${builtins.getEnv "USER"}
                ${pkgs.iproute2}/bin/ip addr add 192.168.100.1/24 dev vm-net
                ${pkgs.iproute2}/bin/ip link set vm-net up
                ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o enp0s20f0u2u3 -j MASQUERADE
              '';
              ExecStart = "${self.packages.${system}.net-vm}/bin/microvm-run net-vm";
              ExecStopPost = "${pkgs.iproute2}/bin/ip link delete vm-net";
            };
            wantedBy = [ "multi-user.target" ];
          };
        }
      ];
    };
  };
}
