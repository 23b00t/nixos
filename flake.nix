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

  outputs = { self, nixpkgs, home-manager, lazyvim-config, ... }@inputs: {
    # Erstelle eine nixpkgs-Instanz, die unfreie Pakete erlaubt.
    # Dies ist der saubere, moderne Weg.
    legacyPackages = forAllSystems:
      let
        pkgs = import nixpkgs {
          system = forAllSystems;
          config.allowUnfree = true;
        };
      in {
        # pkgs wird an die Home-Manager-Konfiguration weitergegeben
      };

    nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      modules = [
        ./machines/d/configuration.nix

        home-manager.nixosModules.home-manager
        {
          # Wir verwenden NICHT mehr die globale Konfiguration.
          home-manager.useGlobalPkgs = false;
          
          # Stattdessen geben wir unsere eigene, `allowUnfree`-fähige pkgs-Instanz.
          home-manager.pkgs = self.legacyPackages.x86_64-linux;

          home-manager.users.nx = {
            imports = [ ./home/home.nix ];
          };

          home-manager.extraSpecialArgs = {
            inherit lazyvim-config;
          };
        }
      ];
    };
  };
}
