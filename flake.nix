{
  description = "Nixos config by 23b00t";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    microvm = {
      url = "github:23b00t/microvm.nix/xen";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NoX (NixOS on Xen): dom0 and VM modules, tools, nox-relay; branch
    # nox-roles until the roles are merged into main
    nox = {
      url = "github:23b00t/NoX/nox-roles";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # wprs fork (branch nox): nixpkgs' wprs with our fixes and flags
    # (modifier sync, back pressure, decompression buffer, clipboard
    # isolation, app id prefix, deny fullscreen)
    wprs = {
      url = "github:23b00t/wprs/nox";
      flake = false;
    };

    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      hardware = import ./machines/hardware.nix { inherit (nixpkgs) lib; };

      # Machines (dom0 with their VMs), one nixosConfiguration per VM, the
      # runners and store images: NoX's flake glue; the domains come from
      # vms/vms.nix, the hardware from machines/hardware.nix
      nox = inputs.nox.lib.mkSystems {
        inherit inputs;
        inherit (hardware) backupLuksUuids;
        vms = ./vms/vms.nix;
        modules = [ ./machines/common-configuration.nix ];
        machines = {
          hp = {
            modules = [ ./machines/hp/configuration.nix ];
            hardware = hardware.machines.hp;
          };
          xmg = {
            modules = [ ./machines/xmg/configuration.nix ];
            hardware = hardware.machines.xmg;
          };
        };
        # The standalone VM outputs see the registry like the xmg
        vmView = "xmg";
        # The builder VMs' public signing keys (signing-key-<machine>.pub,
        # trusted by that dom0's dom0-update) and the commit signers the
        # builder accepts (allowed-signers)
        builderKeys = ./vms/builder;
      };

      # php's PHP shells as flake packages
      vmExtraPackages = import ./vms/php/packages.nix {
        pkgs = import nixpkgs { inherit system; };
      };
    in
    {
      packages.${system} = nox.packages.${system} // vmExtraPackages;

      # NixOS tests (qemu; without KVM, e.g. in a Xen dom0, emulated and slow)
      checks.${system}.sys-vpn-killswitch = nixpkgs.legacyPackages.${system}.testers.runNixOSTest (
        inputs.nox.lib.tests + "/sys-vpn-killswitch.nix"
      );

      nixosConfigurations = nox.nixosConfigurations // {
        default = nox.nixosConfigurations.hp;
      };
    };
}
