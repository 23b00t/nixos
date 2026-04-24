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
      bridgeZones = [
        {
          tapId = "vm-libvirt-default";
          mac = "02:00:00:00:10:00";
          interfaceName = "vm-default";
          addresses = [ "192.168.122.1/24" ];
          provideDhcp4 = true;
        }
        {
          tapId = "vm-whonix-external";
          mac = "02:00:00:00:10:01";
          interfaceName = "vm-whonix-external";
          addresses = [
            "10.0.2.2/24"
            "fd19:c33d:98bc::/64"
          ];
          provideDhcp4 = false;
        }
      ];
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
            let
              bridgeZoneInterfaces = map (zone: zone.interfaceName) bridgeZones;
            in
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
                withDefaultPkgs = false;
              };

              users.users.user.extraGroups = lib.mkAfter [ "networkmanager" ];

              microvm.interfaces = lib.mkAfter (
                map (zone: {
                  type = "tap";
                  id = zone.tapId;
                  mac = zone.mac;
                }) bridgeZones
              );

              systemd.network.links = builtins.listToAttrs (
                map (zone: {
                  name = "20-${zone.interfaceName}";
                  value = {
                    matchConfig.MACAddress = zone.mac;
                    linkConfig.Name = zone.interfaceName;
                  };
                }) bridgeZones
              );

              systemd.network.networks = builtins.listToAttrs (
                map (zone: {
                  name = "30-${zone.interfaceName}";
                  value = {
                    matchConfig.MACAddress = zone.mac;
                    address = zone.addresses;
                    networkConfig = {
                      DHCP = "no";
                      ConfigureWithoutCarrier = true;
                      IPv6AcceptRA = false;
                    };
                    linkConfig.RequiredForOnline = "no";
                  };
                }) bridgeZones
              );

              services.dnsmasq = {
                enable = true;
                extraConfig = ''
                  port=0
                  bind-interfaces
                  interface=vm-default
                  dhcp-range=interface:vm-default,192.168.122.10,192.168.122.200,255.255.255.0,24h
                  dhcp-option=interface:vm-default,option:router,192.168.122.1
                  dhcp-option=interface:vm-default,option:dns-server,9.9.9.9,149.112.112.112

                  interface=vm-whonix-external
                  enable-ra
                  dhcp-range=interface:vm-whonix-external,::,constructor:vm-whonix-external,ra-only,64
                '';
              };

              networking = {
                networkmanager = {
                  enable = true;
                  unmanaged = [ "interface-name:vm-lan" ] ++ map (iface: "interface-name:${iface}") bridgeZoneInterfaces;
                };
                nftables.enable = true;
                firewall = {
                  enable = true;
                  trustedInterfaces = [ "vm-lan" ] ++ bridgeZoneInterfaces;
                  filterForward = true;
                  extraForwardRules = ''
                    iifname "vm-lan" oifname != "vm-lan" accept
                    ${lib.concatMapStringsSep "\n" (iface: "iifname \"${iface}\" oifname != \"${iface}\" accept") bridgeZoneInterfaces}
                    ct state established,related accept
                  '';
                };
                nat = {
                  enable = true;
                  internalInterfaces = [ "vm-lan" ] ++ bridgeZoneInterfaces;
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
                # TODO: Can we set this to true?
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
                    path = "0000:05:00.0"; # Ethernet Controller
                  }
                  {
                    bus = "pci";
                    path = "0000:00:14.3"; # WiFi Controller
                  }
                ];
                mem = 1024;
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
              ];

              system.stateVersion = "26.05";
            }
          )
        ];
      };
    };
}
