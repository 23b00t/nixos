{
  description = "Nixos config by 23b00t";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    microvm = {
      url = "github:23b00t/microvm.nix/xen";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NoX (NixOS on Xen): nox-relay (vchan socket relay), later more tools
    nox = {
      url = "github:23b00t/NoX";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

      registry = import ./vms/registry.nix;
      # Standalone VM outputs (nixosConfigurations.<vm>, packages) see the
      # registry like the xmg host; each host gets its own view in mkMachine
      vmRegistry = registry.forHost "xmg";
      vmDefinitions = import ./vms/definitions.nix { inherit inputs; };

      baseModules = [
        ./machines/common-configuration.nix
      ];

      mkMachine =
        host: extraModules:
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs vmDefinitions;
            vmRegistry = registry.forHost host;
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
            (storeGroups.moduleFor name)
          ];
        };

      vmSystems = builtins.mapAttrs (name: _: mkVmSystem name) vmDefinitions;

      # Group store images, built from the same systems that boot from them
      storeGroups = import ./vms/store-groups.nix {
        inherit (nixpkgs) lib;
        inherit (inputs.microvm.lib) buildStoreDisk;
        inherit vmRegistry vmSystems;
      };

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

      hpConfig = mkMachine "hp" [
        ./machines/hp/configuration.nix
      ];

      xmgConfig = mkMachine "xmg" [
        ./machines/xmg/configuration.nix
      ];
    in
    {
      packages.${system} = vmRunnerPackages // vmExtraPackages;

      nixosConfigurations = vmSystems // {
        hp = hpConfig;
        xmg = xmgConfig;
        default = hpConfig;
      };
    };
}
