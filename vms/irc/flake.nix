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
      lib = nixpkgs.lib;
      index = 5;
      mac = "00:00:00:00:00:05";
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
            (import ../whonix-net-config.nix { inherit lib index mac; })
            (
              { config, ... }:
              {
                networking.hostName = "irc-vm";

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = true;
                  };
                };

                users.groups.irc = { };
                users.users.irc = {
                  password = "trash";
                  isNormalUser = true;
                  group = "irc";
                  extraGroups = [ "wheel" ];
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
                    # {
                    #   mountPoint = "/var";
                    #   image = "var.img";
                    #   size = 8192;
                    # }
                    {
                      mountPoint = "/home/irc";
                      image = "home.img";
                      size = 8192;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 8192;
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
                  mem = 4096;
                };

                environment.systemPackages = with pkgs; [
                  tiny
                  pass
                ];
                system.stateVersion = "25.11";
              }
            )
          ];
        };
      };
    };
}
