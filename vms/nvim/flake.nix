{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "nvim MicroVM";

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
      index = 6;
      mac = "00:00:00:00:00:06";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.nvim;
        nvim = self.nixosConfigurations.irc.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        nvim = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (
              { config, ... }:
              {
                networking.hostName = "nvim-vm";

                users.groups.vim = { };
                users.users.vim = {
                  password = "trash";
                  isNormalUser = true;
                  group = "vim";
                  extraGroups = [ "wheel" ];
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                microvm = {
                  # vsock.cid = 3;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/vim";
                      image = "home.img";
                      size = 8192;
                    }
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
                  ];
                  mem = 4096;
                };

                environment.systemPackages = with pkgs; [
                ];

                programs.neovim = {
                  enable = true;
                  defaultEditor = true;
                  withNodeJs = true;
                  withPython3 = true;
                  extraPackages = with pkgs; [
                    python3
                    fd
                    unzip

                    gcc
                    gnumake

                    nodejs
                    rustc
                    cargo
                    rust-analyzer
                    watchexec

                    lua-language-server
                    nixfmt

                    watchman
                  ];
                };
                home.sessionVariables = {
                  MASON_DIR = "$HOME/.local/share/nvim/mason";
                };

                # direnv
                programs.direnv = {
                  enable = true;
                  nix-direnv.enable = true;
                };
                system.stateVersion = "25.11";
              }
            )
          ];
        };
      };
    };
}
