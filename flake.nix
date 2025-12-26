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

    # MicroVMs
    irc-vm.url = "path:./vms/irc";
    nvim-vm.url = "path:./vms/nvim";
    chat-vm.url = "path:./vms/chat";
    office-vm.url = "path:./vms/office";
    music-vm.url = "path:./vms/music";
    net-vm.url = "path:./vms/net";
    net-private-vm.url = "path:./vms/net-private";
    wine-vm.url = "path:./vms/wine";
    kali-vm.url = "path:./vms/kali";
    vault-vm.url = "path:./vms/vault";
    test-vm.url = "path:./vms/test";

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
