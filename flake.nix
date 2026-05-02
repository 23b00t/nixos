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

    irc = {
      url = "git+file:///home/nx/nixos-config?dir=vms/irc";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    nvim = {
      url = "git+file:///home/nx/nixos-config?dir=vms/nvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    chat = {
      url = "git+file:///home/nx/nixos-config?dir=vms/chat";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    office = {
      url = "git+file:///home/nx/nixos-config?dir=vms/office";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    music = {
      url = "git+file:///home/nx/nixos-config?dir=vms/music";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    net = {
      url = "git+file:///home/nx/nixos-config?dir=vms/net";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    wine = {
      url = "git+file:///home/nx/nixos-config?dir=vms/wine";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    kali = {
      url = "git+file:///home/nx/nixos-config?dir=vms/kali";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    vault = {
      url = "git+file:///home/nx/nixos-config?dir=vms/vault";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    steam = {
      url = "git+file:///home/nx/nixos-config?dir=vms/steam";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    godot = {
      url = "git+file:///home/nx/nixos-config?dir=vms/godot";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    mirage = {
      url = "git+file:///home/nx/nixos-config?dir=vms/mirage";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    php = {
      url = "git+file:///home/nx/nixos-config?dir=vms/php";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    ruby = {
      url = "git+file:///home/nx/nixos-config?dir=vms/ruby";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    sys-usb = {
      url = "git+file:///home/nx/nixos-config?dir=vms/sys-usb";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    sys-net = {
      url = "git+file:///home/nx/nixos-config?dir=vms/sys-net";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    nix = {
      url = "git+file:///home/nx/nixos-config?dir=vms/nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };
    coding = {
      url = "git+file:///home/nx/nixos-config?dir=vms/coding";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.microvm.follows = "microvm";
    };

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
