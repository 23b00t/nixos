{
  description = "Nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # --- NEUER BLOCK ---
    # Füge dein lazyvim-Repo als Input hinzu.
    # Nix wird diesen Ordner jetzt garantiert kennen.
    lazyvim-config = {
      url = "github:23b00t/lazyvim";
      flake = false; # Wichtig, da dein lazyvim-Repo kein Flake ist
    };
    # --- ENDE NEUER BLOCK ---
  };

  outputs = { self, nixpkgs, home-manager, lazyvim-config, ... }@inputs: {
    nixosConfigurations.d = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        # Gib den neuen Input an deine Konfiguration weiter
        inherit lazyvim-config;
      };
      modules = [
        ./machines/d/configuration.nix
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.nx = import ./home/home.nix;
          home-manager.extraSpecialArgs = {
            # Gib den Input auch an Home-Manager weiter
            inherit lazyvim-config;
          };
        }
      ];
    };
  };
}
