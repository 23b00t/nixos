{
  # Use: remote-viewer spice://127.0.0.1:5930 to connect to hyprland
  # nix shell "nixpkgs#virt-viewer"
  description = "onlyoffice MicroVM";

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
      pkgs = import nixpkgs { inherit system; };
      index = 13;
      mac = "00:00:00:00:00:0d";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.onlyoffice;
        onlyoffice = self.nixosConfigurations.onlyoffice.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        onlyoffice = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAd0i0fi7JB5RqYggf9rYsiY5gqXxBUCaqTCBF9ozhSI onlyoffice-vm";
            })
            (import ../yazi-config.nix { inherit pkgs; })
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "onlyoffice-vm";

                microvm = {
                  registerClosure = false;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "qemu";
                  optimize.enable = false;
                  qemu.extraArgs = [
                    "-display"
                    "none"
                    "-device"
                    "virtio-vga,max_outputs=1"
                    "-device"
                    "qemu-xhci"
                    "-device"
                    "virtio-serial-pci"
                    "-device"
                    "virtio-keyboard-pci"
                    "-device"
                    "virtio-tablet-pci"
                    "-chardev"
                    "spicevmc,id=spicechannel0,name=vdagent"
                    "-device"
                    "virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"
                    "-spice"
                    "port=5930,addr=127.0.0.1,disable-ticketing=on,image-compression=off,jpeg-wan-compression=never,zlib-glz-wan-compression=never"
                  ];
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 1000;
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
                  mem = 6000;
                  vcpu = 6;
                };
                services.getty.autologinUser = "user";

                programs.hyprland = {
                  enable = true;
                  withUWSM = true; # recommended for most users
                  xwayland.enable = true; # Xwayland can be disabled.
                };
                services.spice-vdagentd.enable = true;

                services.greetd = {
                  enable = true;
                  settings = rec {
                    initial_session = {
                      command = "${pkgs.hyprland}/bin/start-hyprland";
                      user = "user";
                    };
                    default_session = initial_session;
                  };
                };

                environment.etc."hyprland.conf".source = ./hypr.conf;

                systemd.tmpfiles.rules = [
                  "L+ /home/user/.config/hypr/hyprland.conf - - - - /etc/hyprland.conf"
                ];

                programs.neovim = {
                  enable = true;
                  defaultEditor = true;
                  withNodeJs = true;
                  withPython3 = true;
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    xdg-utils
                    dconf # to fix onlyoffice errors
                    kitty
                    onlyoffice-desktopeditors
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
