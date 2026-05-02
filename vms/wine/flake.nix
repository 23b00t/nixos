# Install protonup-rs proton for steam
# wprs 10.0.0.7 run -- env WINEPREFIX=/home/user/.local/share/wineprefixes/test-app GAMEID=test-app PROTONPATH=/home/user/.steam/root/compatibilitytools.d/GE-Proton10-34 umu-run '/home/user/WISO-Pool/VCE\ Software/VCE\ Exam\ Simulator\ Demo/designer.exe'
# TODO: Add godot like setup (maybe even with gpu passthrough) to make this usefull. Above is very unstable over wprs
{
  description = "Wine MicroVM";

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
        default = self.packages.${system}.wine;
        wine = self.nixosConfigurations.wine.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        wine = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/common-config.nix
            ../modules/net-config.nix
            ../modules/wprs.nix
            (
              { config, pkgs, ... }:
              {
                networking.hostName = "wine-vm";
                nixpkgs.config.allowUnfree = true;

                services.net-config = {
                  enable = true;
                  index = 7;
                  mac = "00:00:00:00:00:07";
                };
                services.common-config = {
                  enable = true;

                };
                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 20000;
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
                  mem = 4048;
                  vcpu = 4;
                };

                environment.systemPackages = [
                  pkgs.protonup-rs
                  pkgs.umu-launcher
                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
