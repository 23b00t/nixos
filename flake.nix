{
  description = "Nixos config by 23b00t";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Dein lazyvim-Repo als garantierte, externe Quelle
    lazyvim-config = {
      url = "github:23b00t/lazyvim";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, lazyvim-config, ... }@inputs: {
    # KORREKTUR: Der Name hier MUSS mit deinem Hostnamen übereinstimmen.
    nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      modules = [
        # Der Pfad zu deiner Systemkonfiguration
        ./machines/d/configuration.nix

        # KORREKTUR: Home-Manager wird als Modul mit den richtigen Argumenten eingebunden
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          
          # Hier wird deine home.nix importiert
          home-manager.users.nx = import ./home/home.nix;

          # KORREKTUR: So wird `lazyvim-config` korrekt an `home.nix` übergeben
          home-manager.extraSpecialArgs = {
            inherit lazyvim-config;
          };
        }
      ];
    };
  };
}
