{
  description = "Chat MicroVM";

  inputs = {
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
      nix-flatpak,
      ...
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      index = 2;
      mac = "00:00:00:00:00:02";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.chat;
        chat = self.nixosConfigurations.chat.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        chat = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            nix-flatpak.nixosModules.nix-flatpak
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "chat-vm";

                users.groups.user = { };
                users.users.user = {
                  password = "trash";
                  isNormalUser = true;
                  group = "user";
                  extraGroups = [
                    "wheel"
                    "video"
                  ];
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqGdw377nJ+Zcf2kXwIiXPi5OFuY5KPOuhi0YaWhGmb chat-vm"
                  ];
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = false;
                  };
                };
                xdg.portal.enable = true;
                xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
                xdg.portal.config.common.default = "gtk";
                services.flatpak = {
                  enable = true;
                  packages = [
                    "us.zoom.Zoom"
                  ];
                };
                # services.flatpak = {
                #   enable = true;
                #   remotes = {
                #     "flathub" = "https://dl.flathub.org/repo/flathub.flatpakrepo";
                #   };
                #   packages = [
                #     "flathub:app/us.zoom.Zoom/x86_64/master"
                #   ];
                #   overrides = {
                #     "us.zoom.Zoom" = {
                #       Context = {
                #         devices = [ "all" ];
                #         sockets = [
                #           "wayland"
                #           "x11"
                #         ];
                #         features = [ "ipc" ];
                #         "talk-name" = [ "org.freedesktop.portal.PipeWire" ];
                #       };
                #     };
                #   };
                # };

                microvm = {
                  registerClosure = false;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "qemu";
                  optimize.enable = false;
                  # qemu.machine = "q35";

                  qemu.extraArgs = [
                    "-nodefaults"
                    "-device"
                    "usb-ehci,id=ehci"
                    "-device"
                    "usb-host,bus=ehci.0,vendorid=0x0408,productid=0x5365,guest-reset=false,pipeline=false"
                  ];

                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 4096;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 4096;
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
                  # devices = [
                  #   {
                  #     bus = "usb";
                  #     path = "vendorid=0x0408,productid=0x5365,guest-reset=false,pipeline=false";
                  #   }
                  # ];
                  mem = 8192;
                  vcpu = 6;
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

                environment.variables = {
                  # Weist Qt an, llvmpipe (einen schnellen CPU-basierten Renderer)
                  # für OpenGL zu verwenden.
                  GALLIUM_DRIVER = "llvmpipe";
                };

                environment.systemPackages = with pkgs; [
                  vesktop
                  telegram-desktop
                  slack
                  # zoom-us
                  google-chrome
                  wprs
                  xwayland
                  usbutils

                  mesa
                  vulkan-loader
                ];

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
