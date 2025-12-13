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
                  # 1. Basic configuration (keep this)
                  enable = true;
                  packages = [
                    # The "full" format is more robust, but the short name will automatically resolve to the correct name after installation.
                    "us.zoom.Zoom"
                  ];

                  # 2. Overrides: Adjustments for Zoom and global defaults
                  overrides = {
                    # Global settings for all Flatpak applications.
                    # A good idea for a consistent system.
                    global = {
                      Context = {
                        # Allows Wayland, but does not explicitly forbid it for X11 applications.
                        # This is safer than forcing Wayland ("!x11").
                        sockets = [ "wayland" ];
                      };
                      Environment = {
                        # Fixes issues with the mouse cursor theme in Wayland.
                        XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
                      };
                    };

                    # Specific and very important overrides for Zoom
                    "us.zoom.Zoom" = {
                      Context = {
                        # Necessary for screen sharing under Wayland.
                        sockets = [
                          "wayland"
                          "x11"
                          "pulseaudio"
                        ];
                        features = [ "ipc" ]; # Allows inter-process communication
                        "talk-name" = [ "org.freedesktop.portal.PipeWire" ]; # PipeWire for screen casting

                        # Allows access to all devices such as cameras and microphones.
                        # This is the simplest way to ensure hardware is detected.
                        devices = [ "all" ];

                        # Optional: Access to the home directory to share files.
                        # ":ro" means "read-only".
                        filesystems = [ "xdg-home:ro" ];
                      };
                    };
                  };

                  # 3. Automatic updates when activating the NixOS generation
                  # Keeps your Flatpaks in sync with your system updates.
                  update.onActivation = true;
                };

                # 4. Automatic restart on installation errors
                # If the Flatpak installation fails (e.g. due to network issues),
                # it will be retried after 60 seconds. Very useful!
                systemd.services.flatpak-managed-install = {
                  restartTriggers = [ config.systemd.services.flatpak-managed-install.path ];
                  serviceConfig = {
                    Restart = "on-failure";
                    RestartSec = "60s";
                  };
                };

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

                # environment.variables = {
                #   # Weist Qt an, llvmpipe (einen schnellen CPU-basierten Renderer)
                #   # für OpenGL zu verwenden.
                #   GALLIUM_DRIVER = "llvmpipe";
                # };

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
