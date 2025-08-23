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
    nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      specialArgs = { inherit lazyvim-config; };
      
      modules = [
        ./machines/d/configuration.nix

        home-manager.nixosModules.home-manager
        {
          # --- DIE KORREKTUR ---
          # 1. Wir sagen Home-Manager, dass es NICHT die globale Konfiguration verwenden soll.
          home-manager.useGlobalPkgs = false;

          # 2. Wir definieren die Konfiguration für den Benutzer `nx`.
          home-manager.users.nx = {
            # 3. Das ist der korrekte Weg: Wir setzen die `nixpkgs`-Konfiguration
            #    direkt hier. Home-Manager erstellt daraufhin seine eigene,
            #    korrekt konfigurierte `pkgs`-Instanz.
            nixpkgs.config.allowUnfree = true;

            # Der Import deiner home.nix bleibt unverändert.
            imports = [ ./home/home.nix ];
          };

          # Extra-Argumente für Home-Manager-Module
          home-manager.extraSpecialArgs = {
            inherit lazyvim-config;
          };
        }
      ];
    };
  };
}
