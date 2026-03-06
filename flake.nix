{
  description = "Nixos config by 23b00t";

    inputs = rec {


    # Your nixpkgs
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.follows = "hydenix/nixpkgs";

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # flatpaks.url = "github:in-a-dil-emma/declarative-flatpak/latest";

      # MicroVMs
      # Derive VM inputs directly from the central registry to avoid manual duplication.
      vmRegistry = import ./vms/registry.nix { inherit (nixpkgs) lib; };

      vmInputs = builtins.listToAttrs (map (vm: {
        name = vm.name;
        value = {
          url = "path:./vms/${vm.name}";
        };
      }) vmRegistry.vms);

    } // vmInputs;



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
    yazi.url = "github:sxyazi/yazi";

    # Hardware Configuration's, used in ./configuration.nix. Feel free to remove if unused
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
  };

  outputs =
    { ... }@inputs:
    let
      system = "x86_64-linux";
      hydenixConfig = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
        };
        # extraModules = [
        #   (
        #     { pkgs, ... }:
        #     {
        #       nixpkgs.overlays = [
        #         (import ./overlays/socktop.nix)
        #       ];
        #     }
        #   )
        # ];
        modules = [
          ./machines/configuration.nix
        ];
      };

    in
    {
      nixosConfigurations = {
        hydenix = hydenixConfig;
        default = hydenixConfig;
        machine = hydenixConfig;
      };
    };
}
