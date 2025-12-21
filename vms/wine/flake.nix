{
  description = "Wine MicroVM";

  inputs = {
    microvm = {
      url = "github:astro/microvm.nix";
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
      index = 7;
      mac = "00:00:00:00:00:07";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.wine;
        wine = self.nixosConfigurations.wine.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        wine = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRYiHWjGyucuX6XJq2U3ENx7MHACcX0t8YzB2JEgfyR wine-vm";
            })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "wine-vm";

                microvm = {
                  registerClosure = false;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 2048;
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
                  mem = 4048;
                  vcpu = 2;
                };

                # Setup xrdp with fluxbox
                networking.firewall = {
                  allowedTCPPorts = [ 3389 ];
                  allowedUDPPorts = [ 3389 ];
                };
                services.xrdp = {
                  enable = true;
                  audio.enable = true;
                  defaultWindowManager = ''
                    exec fluxbox -no-toolbar &
                    fbpid=$!
                    sleep 2
                    setxkbmap -layout "us" -variant "intl" -option "grp:alt_shift_toggle"
                    kitty &
                    wait $fbpid
                  '';
                };
                services.xserver.enable = true;
                services.xserver.windowManager.fluxbox.enable = true;

                environment.systemPackages = [
                  pkgs.wine
                  pkgs.kitty
                  pkgs.wprs
                  pkgs.xwayland
                  (import ../copy-between-vms.nix { inherit pkgs; })
                ]
                ++ defaultPkgs;

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
