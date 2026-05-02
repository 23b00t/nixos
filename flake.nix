{
  description = "Nixos config by 23b00t";

  inputs = rec {
    # Your nixpkgs
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

    # Hardware Configuration's, used in ./configuration.nix. Feel free to remove if unused
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    irc.url = "git+file:///home/nx/nixos-config?dir=vms/irc";
    nvim.url = "git+file:///home/nx/nixos-config?dir=vms/nvim";
    chat.url = "git+file:///home/nx/nixos-config?dir=vms/chat";
    office.url = "git+file:///home/nx/nixos-config?dir=vms/office";
    music.url = "git+file:///home/nx/nixos-config?dir=vms/music";
    net.url = "git+file:///home/nx/nixos-config?dir=vms/net";
    wine.url = "git+file:///home/nx/nixos-config?dir=vms/wine";
    kali.url = "git+file:///home/nx/nixos-config?dir=vms/kali";
    vault.url = "git+file:///home/nx/nixos-config?dir=vms/vault";
    steam.url = "git+file:///home/nx/nixos-config?dir=vms/steam";
    godot.url = "git+file:///home/nx/nixos-config?dir=vms/godot";
    mirage.url = "git+file:///home/nx/nixos-config?dir=vms/mirage";
    php.url = "git+file:///home/nx/nixos-config?dir=vms/php";
    ruby.url = "git+file:///home/nx/nixos-config?dir=vms/ruby";
    sys-usb.url = "git+file:///home/nx/nixos-config?dir=vms/sys-usb";
    sys-net.url = "git+file:///home/nx/nixos-config?dir=vms/sys-net";
    nix.url = "git+file:///home/nx/nixos-config?dir=vms/nix";
    coding.url = "git+file:///home/nx/nixos-config?dir=vms/coding";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
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
    in
    {
      nixosConfigurations = {
        xmg = xmgConfig;

        default = xmgConfig;
      };
    };
}
