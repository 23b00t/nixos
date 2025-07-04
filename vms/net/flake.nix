{
  description = "NixOS in MicroVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    microvm.url = "github:astro/microvm.nix";
    
    # home-manager als separater Input
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, microvm, home-manager }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      index = 1;
      mac = "00:00:00:00:00:01";
    in {
      packages.${system} = {
        default = self.packages.${system}.net-vm;
        net-vm = self.nixosConfigurations.net-vm.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        net-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            home-manager.nixosModules.home-manager
            ({ config, ... }: {
              networking.hostName = "net-vm";

              # Home Manager-Konfiguration
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.nx = import ./home/home.nix;
              };

              microvm = {
                writableStoreOverlay = "/nix/.rw-store";
                hypervisor = "cloud-hypervisor";
                interfaces = [{
                  id = "vm${toString index}";
                  type = "tap";
                  inherit mac;
                }];
                volumes = [
                  { 
                    mountPoint = "/var";
                    image = "var.img";
                    size = 256;
                  }
                  { 
                    mountPoint = "/home/nx";
                    image = "home.img";
                    size = 8192;
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
                mem = 2096;
              };
              boot.initrd.postDeviceCommands = lib.mkForce "";
              system.stateVersion = lib.trivial.release;

              services.getty.autologinUser = "nx";
              users.users.nx = {
                password = "trash";
                group = "nx";
                isNormalUser = true;
                extraGroups = [ "wheel" "video" ];
                openssh.authorizedKeys.keys = [ 
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINB4DnXkH9Y/XWof2jgTkrdCrc7X9OtlxQI69L8U81P9 nx@machine"
                ];
              };
              users.groups.nx = {};
              security.sudo = {
                enable = true;
                wheelNeedsPassword = false;
              };

              environment.systemPackages = with pkgs; [
                waypipe
              ];
                            
              hardware.graphics.enable = true;

              networking.useNetworkd = true;

              # ssh for waypipe
              services.openssh = {
                enable = true;
                settings = {
                  PasswordAuthentication = false;
                  PubkeyAuthentication = true;
                  PermitRootLogin = "no";
                };
              };
              
              # Audio in der MicroVM
              services.pulseaudio.enable = false;
              services.pipewire = {
                enable = true;
                pulse.enable = true;
              };

              # Umgebungsvariable für alle User
              environment.sessionVariables = {
                PULSE_SERVER = "tcp:localhost:4713";
              };

              systemd.network.networks."10-eth" = {
                matchConfig.MACAddress = mac;
                address = [
                  "10.0.0.${toString index}/32"
                  "fec0::${lib.toHexString index}/128"
                ];
                routes = [
                  { Destination = "10.0.0.0/32"; GatewayOnLink = true; }
                  { Destination = "0.0.0.0/0"; Gateway = "10.0.0.0"; GatewayOnLink = true; }
                  { Destination = "::/0"; Gateway = "fec0::"; GatewayOnLink = true; }
                ];
                networkConfig = {
                  DNS = [
                    "9.9.9.9"
                    "149.112.112.112"
                    "2620:fe::fe"
                    "2620:fe::9"
                  ];
                };
              };
            }
            )
          ];
        };
      };
    };
}
