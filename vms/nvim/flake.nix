{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "nvim MicroVM";

  inputs.microvm = {
    url = "github:astro/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
      home-manager,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      index = 6;
      mac = "00:00:00:00:00:06";
    in
    {
      nixpkgs.pkgs = pkgs;
      packages.${system} = {
        default = self.packages.${system}.nvim;
        nvim = self.nixosConfigurations.nvim.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        nvim = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            home-manager.nixosModules.home-manager
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "nvim-vm";

                programs.zsh.enable = true;
                users.defaultUserShell = pkgs.zsh;

                users.groups.nvim = { };
                users.users.nvim = {
                  password = "trash";
                  isNormalUser = true;
                  group = "nvim";
                  extraGroups = [ "wheel" ];
                  shell = pkgs.zsh;
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                microvm = {
                  registerClosure = false;
                  # vsock.cid = 3;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    # {
                    #   mountPoint = "/home/nvim";
                    #   image = "home.img";
                    #   size = 8192;
                    # }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 8192;
                    }
                  ];
                  shares = [
                    {
                      proto = "virtiofs";
                      tag = "ro-store";
                      source = "/nix/store";
                      mountPoint = "/nix/.ro-store";
                    }
                    {
                      proto = "virtiofs";
                      tag = "home";
                      source = "/home/nx";
                      mountPoint = "/home/nvim";
                    }
                  ];
                  mem = 4096;
                };

                environment.systemPackages = with pkgs; [
                  devenv
                ];

                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users.nvim = import ./nvim-home.nix;
                };
                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
