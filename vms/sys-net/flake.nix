{
  description = "sys-net MicroVM";

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
    in
    {
      packages.${system} = {
        default = self.packages.${system}.sys-net;
        sys-net = self.nixosConfigurations.sys-net.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        sys-net = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "sys-net-vm";
                services.net-config = {
                  enable = true;
                  index = 17;
                  mac = "00:00:00:00:00:11";
                };

                microvm = {
                  registerClosure = false;

                  hypervisor = "cloud-hypervisor";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 5000;
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
                  devices = [
                    {
                      bus = "pci";
                      path = "0000:05:00.0";
                    }
                    {
                      bus = "pci";
                      path = "0000:00:14.3";
                    }
                  ];
                  mem = 2048;
                  vcpu = 1;
                };

                environment.systemPackages = with pkgs; [
                  vim
                  btop
                  networkmanager
                  iw
                  ethtool
                  iproute2
                  wireless_tools
                  wpa_supplicant
                ];

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = false;
                  };
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };
                users.groups.users = { };

                users.users.user = {
                  isNormalUser = true;
                  group = "users";
                  extraGroups = [
                    "wheel"
                  ];
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/v5mOcbtZ/shL0s5Y2xJYkfEdkPMsznhEC3X7cGgmL sys-net-vm"
                  ];
                };

                environment.etc."ssh_config".text = ''
                  Host *
                      StrictHostKeyChecking no
                      UserKnownHostsFile /dev/null
                  Host 10.0.0.254 
                      IdentitiesOnly yes
                '';

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
