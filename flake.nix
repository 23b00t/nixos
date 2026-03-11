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

    irc.url = "path:./vms/irc";
    nvim.url = "path:./vms/nvim";
    chat.url = "path:./vms/chat";
    office.url = "path:./vms/office";
    music.url = "path:./vms/music";
    net.url = "path:./vms/net";
    net-private.url = "path:./vms/net-private";
    wine.url = "path:./vms/wine";
    kali.url = "path:./vms/kali";
    vault.url = "path:./vms/vault";
    # test.url = "path:./vms/test";
    # onlyoffice.url = "path:./vms/onlyoffice";
    steam.url = "path:./vms/steam";
    godot.url = "path:./vms/godot";
    mirage.url = "path:./vms/mirage";
    php.url = "path:./vms/php";
  };

  outputs =
    { ... }@inputs:
    let
      system = "x86_64-linux";

      # Import vm registry as pure data (registry.nix should not depend on lib)
      vmRegistry = import ./vms/registry.nix;

      # Build a set of VM flakes from the registry, so we can pass them into configuration.
      vmFlakes = builtins.listToAttrs (map (vm: {
        name = vm.name;
        value = inputs.${vm.name};
      }) vmRegistry.vms);

      hydenixConfig = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs vmRegistry vmFlakes;
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
