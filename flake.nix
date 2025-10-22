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
    hydenix = {
      url = "github:richen604/hydenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    {
      nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./machines/h/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = false;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.nx = {
              nixpkgs.config.allowUnfree = true;
              imports = [ ./home/home.nix ];
            };
          }

          hydenix.nixosModules.default

          nix-ld.nixosModules.nix-ld
          # ./nix-ld-config.nix

          # The module in this repository defines a new module under (programs.nix-ld.dev) instead of (programs.nix-ld)
          # to not collide with the nixpkgs version.
          # { programs.nix-ld.dev.enable = true; }
        ];
      };
    };
}
