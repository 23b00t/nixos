{
  description = "Nixos config by 23b00t";

  inputs = rec {
    # Your nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

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
        #         (final: prev: {
        #           # Replace problematic hyde-ipc with a dummy that notifies user it's disabled
        #           hyde-ipc = prev.runCommand "hyde-ipc-dummy" { } ''
        #             mkdir -p $out/bin
        #             echo "echo hyde-ipc is disabled" > $out/bin/hyde-ipc
        #             chmod +x $out/bin/hyde-ipc
        #           '';
        #         })
        #       ];
        #       # OR:
        #       nixpkgs.overlays = [
        #         (final: prev: {
        #           hyde-ipc =
        #             (import (fetchTarball {
        #               url = "https://github.com/NixOS/nixpkgs/archive/<ALT_COMMIT>.tar.gz";
        #             }) { system = prev.system; }).hyde-ipc;
        #         })
        #       ];
        #     }
        #   )
        # ];
        modules = [
          ./machines/h/configuration.nix
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
