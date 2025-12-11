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
      pkgs = nixpkgs.legacyPackages.${system};
      index = 5;
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
            (import ../whonix-net-config.nix { inherit index; })
            (
              { config, ... }:
              {
                microvm.interfaces = [
                  {
                    type = "tap";
                    id = "vm5";
                    mac = "02:00:00:00:00:05";
                  }
                  {
                    type = "tap";
                    id = "vm5-tor";
                    mac = "02:00:00:00:00:06";
                  }
                ];
                networking.hostName = "irc-vm";

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = false;
                  };
                };

                users.groups.user = { };
                users.users.user = {
                  password = "trash";
                  isNormalUser = true;
                  group = "user";
                  extraGroups = [ "wheel" ];
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIi5GV6zFAWtdZu3NoVn/48ntuGf6nSpC/eoi5cxJyoZ irc-vm"
                  ];
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                microvm = {
                  # vsock.cid = 3;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/irc";
                      image = "home.img";
                      size = 512;
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

                environment.systemPackages = with pkgs; [
                  tiny
                  pass
                  gnupg
                  pinentry-curses
                  proxychains-ng
                  openssl
                ];

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
