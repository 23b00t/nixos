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
      # 1. Definiere die pkgs-Instanz mit allowUnfree.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
        inherit system;
        
        specialArgs = { inherit lazyvim-config; };
        
        modules = [
          ./machines/d/configuration.nix

          home-manager.nixosModules.home-manager
          {
            # 2. Definiere die Konfiguration für den Benutzer 'nx'.
            home-manager.users.nx = {
              # 3. KORREKTUR: Weise die pkgs-Instanz hier zu.
              #    Die Option heißt `pkgs`, nicht `home-manager.pkgs`.
              pkgs = pkgs;

              # Der Import deiner home.nix
              imports = [ ./home/home.nix ];
            };

            # Es ist wichtig, `useGlobalPkgs` auf `false` zu setzen,
            # damit die obige `pkgs`-Zuweisung respektiert wird.
            home-manager.useGlobalPkgs = false;

            # Extra-Argumente für Home-Manager-Module
            home-manager.extraSpecialArgs = {
              inherit lazyvim-config;
            };
          }
        ];
      };
    };
}
