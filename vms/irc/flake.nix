{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "IRC MicroVM";

  inputs.microvm = {
    url = "github:astro/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
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
      index = 11;
    in
    {
      packages.${system} = {
        default = self.packages.${system}.irc;
        irc = self.nixosConfigurations.irc.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        irc = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../whonix-net-config.nix {
              inherit index;
              inherit lib;
            })
            (import ../common-config.nix {
              inherit lib;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIi5GV6zFAWtdZu3NoVn/48ntuGf6nSpC/eoi5cxJyoZ irc-vm";
            })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                microvm.interfaces = [
                  {
                    type = "tap";
                    id = "vm${toString index}";
                    mac = "02:00:00:00:00:0b";
                  }
                  {
                    type = "tap";
                    id = "vm${toString index}-tor";
                    mac = "02:00:00:00:00:0c";
                  }
                ];
                networking.hostName = "irc-vm";

                microvm = {
                  # vsock.cid = 3;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 512;
                    }
                    {
                      mountPoint = "/var/log";
                      image = "log.img";
                      size = 1028;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 2048;
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
                };

                environment.etc."ssh_config".text = ''
                  Host *
                      StrictHostKeyChecking no
                      UserKnownHostsFile /dev/null
                '';
                systemd.tmpfiles.rules = [
                  "L+ /home/user/.ssh/config - - - - /etc/ssh_config"
                ];

                environment.systemPackages = with pkgs; [
                  tiny
                  pass
                  gnupg
                  pinentry-curses
                  proxychains-ng
                  openssl

                  (import ../copy-between-vms.nix { inherit pkgs; })
                ] ++ defaultPkgs;

                environment.etc."proxychains.conf".text = ''
                  [ProxyList]
                  socks5  10.152.152.10 9050
                '';
                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
