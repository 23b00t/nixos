{
  description = "Nixos config by 23b00t";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yazi.url = "github:sxyazi/yazi";

    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";

      vmRegistry = import ./vms/registry.nix;
      vmDefinitions = import ./vms/definitions.nix { inherit inputs; };

      baseModules = [
        ./machines/common-configuration.nix
      ];

      mkMachine =
        extraModules:
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs vmRegistry vmDefinitions;
          };
          modules = baseModules ++ extraModules;
        };

      mkVmSystem =
        name:
        let
          vmDefinition = vmDefinitions.${name};
        in
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs vmRegistry;
          }
          // (vmDefinition.specialArgs or { });
          modules = [
            inputs.microvm.nixosModules.microvm
            vmDefinition.module
          ];
        };

      vmSystems = builtins.mapAttrs (name: _: mkVmSystem name) vmDefinitions;

      vmRunnerPackages = builtins.mapAttrs (
        _: vmSystem: vmSystem.config.microvm.declaredRunner
      ) vmSystems;

      vmExtraPackages =
        let
          pkgs = import nixpkgs { inherit system; };
        in
        builtins.foldl' (
          acc: name:
          let
            vmDefinition = vmDefinitions.${name};
            extraPackages = (vmDefinition.packages or (_: { })) { inherit pkgs; };
          in
          acc // extraPackages
        ) { } (builtins.attrNames vmDefinitions);

      hpConfig = mkMachine [
        ./machines/hp/configuration.nix
      ];
    in
    {
      packages.${system} = vmRunnerPackages // vmExtraPackages;

      nixosConfigurations = vmSystems // {
        hp = hpConfig;
        default = hpConfig;
      };
    };
}

