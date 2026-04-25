{
  description = "Chat MicroVM";

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
      ...
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
      vmRegistry = import ../registry.nix;
      usb = vmRegistry.hardware.usb.byName;
      defaultUsbDevices = vmRegistry.hardware.usb.defaultForOwner "chat";
      webcamUsbDevice = builtins.head defaultUsbDevices;
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
            ../modules/net-config.nix
            ../modules/common-config.nix
            (
              { config, pkgs, ... }:
              {
                services.net-config = {
                  enable = true;
                  index = 2;
                  mac = "00:00:00:00:00:02";
                };
                services.common-config = {
                  enable = true;
                  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqGdw377nJ+Zcf2kXwIiXPi5OFuY5KPOuhi0YaWhGmb chat-vm";
                };
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "chat-vm";

                microvm = {
                  registerClosure = false;
                  hypervisor = "qemu";
                  optimize.enable = false;

                  qemu.extraArgs = [
                    "-nodefaults"
                    "-device"
                    "usb-ehci,id=ehci"
                    "-device"
                    "usb-host,bus=ehci.0,${webcamUsbDevice.microvmUsbPath},guest-reset=false,pipeline=false"
                  ];

                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
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
                  mem = 8192;
                  vcpu = 2;
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

                services.gnome.gnome-keyring.enable = true;

                environment.systemPackages = with pkgs; [
                  vesktop
                  telegram-desktop
                  slack
                  element-desktop
                  google-chrome
                  wprs
                  xwayland

                  mesa
                  vulkan-loader

                  kitty
                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
