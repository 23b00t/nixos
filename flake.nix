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

    # Hydenix
    hydenix = {
      url = "github:richen604/hydenix";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    yazi.url = "github:sxyazi/yazi";

    # Hardware Configuration's, used in ./configuration.nix. Feel free to remove if unused
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    # MicroVMs – derive from registry
    vmRegistry = import ./vms/registry.nix;

    vmInputs = builtins.listToAttrs (map (vm: {
      name = vm.name;
      value = {
        url = "path:./vms/${vm.name}";
      };
    }) vmRegistry.vms);
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
