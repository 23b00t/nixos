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

      vmRegistry = import ./vms/registry.nix;

      vmFlakes = builtins.listToAttrs (
        map (vm: {
          name = vm.name;
          value = inputs.${vm.name};
        }) vmRegistry.vms
      );

      baseModules = [
        ./machines/common-configuration.nix
      ];

      mkMachine =
        extraModules:
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs vmRegistry vmFlakes;
          };
          modules = baseModules ++ extraModules;
        };

      xmgConfig = mkMachine [
        ./machines/xmg/configuration.nix
      ];

      hpConfig = mkMachine [
        ./machines/hp/configuration.nix
      ];
    in
    {
      nixosConfigurations = {
        xmg = xmgConfig;
        hp = hpConfig;

        default = xmgConfig;
      };
    };
}
