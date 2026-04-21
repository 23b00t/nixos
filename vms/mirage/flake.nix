{
  description = "mirage MicroVM";

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
        default = self.packages.${system}.mirage;
        mirage = self.nixosConfigurations.mirage.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        mirage = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/common-config.nix
            ../modules/ide.nix
            ../modules/zsh.nix
            (
              { config, pkgs, ... }:
              {
                networking.hostName = "mirage-vm";
                services.net-config = {
                  enable = true;
                  index = 14;
                  mac = "00:00:00:00:00:0e";
                };
                services.ide.enable = true;
                services.zsh-env.enable = true;
                services.common-config = {
                  enable = true;
                  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAXSVOR0aTAo/5lDeG+3r3QeOygbLKY7WrkB8wSK+rh9 mirage-vm";
                };

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 12000;
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
                  vcpu = 4;
                };

                environment.systemPackages = with pkgs; [
                  opam
                  mercurial
                  darcs
                  bubblewrap
                  gcc
                  gnumake
                  pkg-config
                  rsync
                  pkg-config
                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
