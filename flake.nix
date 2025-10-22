{
  description = "Nixos config by 23b00t";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ld = {
      url = "github:nix-community/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    yazi.url = "github:sxyazi/yazi";
    # Hydenix
    hydenix = {
      # Available inputs:
      # Main: github:richen604/hydenix
      # Commit: github:richen604/hydenix/<commit-hash>
      # Version: github:richen604/hydenix/v1.0.0 - note the version may not be compatible with this template
      url = "github:richen604/hydenix";

      # uncomment the below if you know what you're doing, hydenix updates nixos-unstable every week or so
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-ld,
      hydenix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          (final: prev: {
            python-pyamdgpuinfo = prev.python3Packages.pyamdgpuinfo;
          })
        ];
      };
      hydenixConfig = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./machines/h/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = false;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.nx = {
              nixpkgs.config.allowUnfree = true;
              imports = [
                ./home/home.nix
                # inputs.hydenix.homeModules.default
              ];
            };
          }

          nixpkgs.nixosModules.readOnlyPkgs
          # nix-ld.nixosModules.nix-ld
          # ./nix-ld-config.nix
          # The module in this repository defines a new module under (programs.nix-ld.dev) instead of (programs.nix-ld)
          # to not collide with the nixpkgs version.
          # { programs.nix-ld.dev.enable = true; }
        ];
      };
    in
    {
      nixosConfigurations.machine = hydenixConfig;
      nixosConfigurations.hydenix = hydenixConfig;
      nixosConfigurations.default = hydenixConfig;
    };
}
