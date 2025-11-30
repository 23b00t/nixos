{
  description = "Chat MicroVM";

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
      index = 2;
      mac = "00:00:00:00:00:02";
    in
    {
      nixpkgs.pkgs = pkgs;
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
                  extraGroups = [ "wheel" ];
                  # openssh.authorizedKeys.keys = [
                  #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzJjZw0V2CdaWI/IBFcTQPwQhYtFn/31i5iNPSc1j8G chat-vm"
                  # ];
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = true;
                  };
                };
                microvm = {
                  registerClosure = false;
                  # vsock.cid = 3;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
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
                  mem = 8192;
                  vcpu = 3;
                };

                environment.systemPackages = with pkgs; [
                  vesktop
                  telegram-desktop
                  slack
                ];

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
