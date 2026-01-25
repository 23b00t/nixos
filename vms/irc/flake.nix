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
      pkgs = import nixpkgs { inherit system; };
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
              inherit pkgs;
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

                environment.etc."zellij".source = ./zellij;
                systemd.tmpfiles.rules = [
                  # zellij config
                  "d /home/user/.config/zellij 0755 user user -"
                  "L+ /home/user/.config/zellij/config.kdl - - - - /etc/zellij/config.kdl"
                  "L+ /home/user/.config/zellij/layouts - - - - /etc/zellij/layouts"
                  "L+ /home/user/.config/zellij/plugins - - - - /etc/zellij/plugins"
                ];

                environment.systemPackages =
                  with pkgs;
                  [
                    tiny
                    pass
                    gnupg
                    pinentry-curses
                    proxychains-ng
                    openssl
                    zellij
                    iamb

                    (import ../copy-between-vms.nix { inherit pkgs; })
                  ]
                  ++ defaultPkgs;

                environment.etc."proxychains.conf".text = ''
                  [ProxyList]
                  socks5  10.152.152.10 9050
                '';

                programs.vim = {
                  enable = true;
                  defaultEditor = true;
                };
                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
