{
  description = "sys-net MicroVM";

  inputs = {
    microvm = {
      url = "github:microvm-nix/microvm.nix";
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
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages.${system} = {
        default = self.packages.${system}.sys-net;
        sys-net = self.nixosConfigurations.sys-net.config.microvm.declaredRunner;
      };

      nixosConfigurations.sys-net = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          ../modules/net-config.nix
          ../modules/common-config.nix
          (
            { lib, ... }:
            {
              networking.hostName = "sys-net-vm";

              services.net-config = {
                enable = true;
                tapId = "vm-router";
                interfaceName = "vm-lan";
                address4 = "10.0.0.253/24";
                gateway4 = null;
                mac = "00:00:00:00:00:11";
              };

              services.common-config = {
                enable = true;
                sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2rxZHd/9pzQeQz3VDwlpcEP9KGOASXYsajKbcZdJ4/ sys-net-vm";
              };

              users.users.user.extraGroups = lib.mkAfter [ "networkmanager" ];

              networking = {
                networkmanager = {
                  enable = true;
                  unmanaged = [ "interface-name:vm-lan" ];
                };
                nftables.enable = true;
                firewall = {
                  enable = true;
                  trustedInterfaces = [ "vm-lan" ];
                  filterForward = true;
                  extraForwardRules = ''
                    iifname "vm-lan" oifname != "vm-lan" accept
                    ct state established,related accept
                  '';
                };
                nat = {
                  enable = true;
                  internalInterfaces = [ "vm-lan" ];
                };
              };

              boot.kernel.sysctl = {
                "net.ipv4.ip_forward" = 1;
                "net.ipv6.conf.all.forwarding" = 1;
              };

              hardware.enableRedistributableFirmware = true;

              systemd.services.NetworkManager-wait-online.enable = false;

              microvm = {
                registerClosure = false;
                hypervisor = "cloud-hypervisor";
                optimize.enable = false;
                volumes = [
                  {
                    mountPoint = "/home/user";
                    image = "home.img";
                    size = 5000;
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
                devices = [
                  {
                    bus = "pci";
                    path = "0000:05:00.0";
                  }
                  {
                    bus = "pci";
                    path = "0000:00:14.3";
                  }
                ];
                mem = 2048;
                vcpu = 1;
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

              environment.systemPackages = with pkgs; [
                vim
                btop
                networkmanager
                networkmanagerapplet
                iw
                ethtool
                iproute2
                wirelesstools
                wpa_supplicant
                dnsutils
                tcpdump
                nftables

                wprs
                xwayland

                pciutils
              ];

              system.stateVersion = "26.05";
            }
          )
        ];
      };
    };
}
