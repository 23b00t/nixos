{
  description = "test MicroVM";

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
      pkgs = import nixpkgs { inherit system; };
      index = 3;
      mac = "00:00:00:00:00:03";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.test;
        test = self.nixosConfigurations.test.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        test = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2091GSIL+SlR1BsWswg+6DZzrL+enxmXo74d/OSUwv test-vm";
            })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "test-vm";

                users.users.user.extraGroups = lib.mkAfter [ "video" ];
                microvm = {
                  registerClosure = false;
                  writableStoreOverlay = "/nix/.rw-store";
                  # hypervisor = "cloud-hypervisor";
                  graphics.enable = true;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 4096;
                    }
                    {
                      mountPoint = "/var/log";
                      image = "log.img";
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

                environment.sessionVariables = {
                  WAYLAND_DISPLAY = "wayland-1";
                  DISPLAY = ":0";
                  QT_QPA_PLATFORM = "wayland"; # Qt Applications
                  GDK_BACKEND = "wayland"; # GTK Applications
                  XDG_SESSION_TYPE = "wayland"; # Electron Applications
                  SDL_VIDEODRIVER = "wayland";
                  CLUTTER_BACKEND = "wayland";
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    godot_4
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
