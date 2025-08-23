{
  description = "Nixos config by 23b00t";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lazyvim-config = {
      url = "github:23b00t/lazyvim";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, lazyvim-config, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
        inherit system;
        
        specialArgs = { inherit lazyvim-config; }; # `specialArgs` für NixOS-Module
        
        modules = [
          ./machines/d/configuration.nix

          # Konfiguriere das Home-Manager Modul
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = false; # Wichtig: Wir nutzen nicht die globalen pkgs
            home-manager.pkgs = pkgs; # Sondern unsere eigene, `allowUnfree`-fähige Instanz

            home-manager.users.nx = {
              imports = [ ./home/home.nix ];
            };

            # `extraSpecialArgs` für Home-Manager Module
            home-manager.extraSpecialArgs = {
              inherit lazyvim-config;
            };
          }
        ];
      };
    };
}
