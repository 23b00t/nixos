{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "nvim MicroVM";

  inputs.microvm = {
    url = "github:microvm-nix/microvm.nix";
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
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        default = self.packages.${system}.nvim;
        nvim = self.nixosConfigurations.nvim.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        nvim = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/yazi-config.nix
            ../modules/ide.nix
            ../modules/zsh.nix
            ../modules/zellij.nix
            ../modules/common-config.nix
            (
              { config, pkgs, ... }:
              {
                networking.hostName = "nvim-vm";

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
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
                      tag = "host-home";
                      source = "/home/nx";
                      mountPoint = "/mnt/host";
                    }
                    {
                      proto = "virtiofs";
                      tag = "ro-store";
                      source = "/nix/store";
                      mountPoint = "/nix/.ro-store";
                    }
                  ];
                  mem = 4096;
                  vcpu = 1;
                };

                environment.systemPackages = with pkgs; [
                  lua-language-server
                  lua51Packages.lua
                  lua51Packages.luarocks
                  nixfmt
                  nil
                  nixdoc
                ];

                services.net-config = {
                  enable = true;
                  index = 1;
                  mac = "00:00:00:00:00:01";
                };
                services.common-config = {
                  enable = true;
                };

                services.ide = {
                  enable = true;
                  githubAgent.enable = true;
                  lazyvimRepo = "git@github.com:23b00t/lazyvim.git";
                };

                services.zellij-env = {
                  enable = true;
                  # Defaults for reference
                  # user = "user";
                  # configDir = ./zellij-custom;
                  tabsKdlFile = builtins.path {
                    name = "tabs.kdl";
                    path = ./tabs.kdl;
                  };
                };

                services.zsh-env = {
                  enable = true;
                  # Defaults for reference
                  # user = "user";
                  ohMyPoshTheme = "1_shell.omp.json";

                  extraAliases = {
                    edit = "sudo -e";
                  };
                };

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
