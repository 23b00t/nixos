{
  description = "Nixos config by 23b00t";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    microvm = {
      url = "github:23b00t/microvm.nix/xen";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NoX (NixOS on Xen): dom0 and VM modules, tools, nox-relay; branch
    # nox-modules until the modularization is merged into main
    nox = {
      url = "github:23b00t/NoX/nox-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # wprs fork (branch nox): nixpkgs' wprs with our fixes and flags
    # (modifier sync, back pressure, decompression buffer, clipboard
    # isolation, app id prefix, deny fullscreen)
    wprs = {
      url = "github:23b00t/wprs/nox";
      flake = false;
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
        inputs.nox.nixosModules.dom0-base
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
      storeGroups = import (inputs.nox.lib.vms + "/store-groups.nix") {
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

      # NixOS tests (qemu; without KVM, e.g. in a Xen dom0, emulated and slow)
      checks.${system}.sys-vpn-killswitch =
        nixpkgs.legacyPackages.${system}.testers.runNixOSTest
          (inputs.nox.lib.tests + "/sys-vpn-killswitch.nix");

      nixosConfigurations = vmSystems // {
        hp = hpConfig;
        xmg = xmgConfig;
        default = hpConfig;
      };
    };
}
