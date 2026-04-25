{
  description = "sys-usb MicroVM";

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
      vmRegistry = import ../registry.nix;
      usb = vmRegistry.hardware.usb.byName;
      sysUsbIp = vmRegistry.byName."sys-usb".ip;
      defaultUsbDevices = vmRegistry.hardware.usb.defaultForOwner "sys-usb";
      mkUsbDevice = device: {
        bus = "usb";
        path = device.microvmUsbPath;
      };
    in
    {
      packages.${system} = {
        default = self.packages.${system}.sys-usb;
        sys-usb = self.nixosConfigurations.sys-usb.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        sys-usb = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/common-config.nix
            ../modules/yazi-config.nix
            (
              { config, pkgs, ... }:
              {
                networking.hostName = "sys-usb-vm";
                services.net-config = {
                  enable = true;
                  tapId = "vm-usb";
                  interfaceName = "vm-lan";
                  address4 = "${sysUsbIp}/24";
                  mac = "00:00:00:00:00:fc";
                };

                services.common-config = {
                  enable = true;
                  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIsMuzfPPoWJ9bgKKPBWx/l5qYuWtwEG5s/yHs4rUrJn sys-usb-vm";
                  withDefaultPkgs = false;
                };

                boot.kernelModules = [
                  "btusb"
                  "btintel"
                ];

                microvm = {
                  registerClosure = false;

                  hypervisor = "qemu";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 10000;
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
                  devices = map mkUsbDevice defaultUsbDevices;
                  mem = 1024;
                  vcpu = 1;
                };

                environment.systemPackages = with pkgs; [
                  blueman
                  bluez
                  bluez-tools
                  dbus
                  wprs
                  xwayland
                ];

                services.dbus.enable = true;
                programs.dconf.enable = true;

                # NOTE:
                # bluetoothctl
                # power on
                # agent on
                # default-agent
                # scan on
                # pair AA:BB:CC:DD:EE:FF
                # trust AA:BB:CC:DD:EE:FF
                # connect AA:BB:CC:DD:EE:FF
                #
                services.blueman.enable = true;
                hardware.enableRedistributableFirmware = true;
                hardware.bluetooth = {
                  enable = true;
                  settings = {
                    General = {
                      AutoEnable = true;
                      FastConnectable = true;
                    };
                  };
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
                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
