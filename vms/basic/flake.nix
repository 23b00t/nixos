{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "Basic MicroVM";

  inputs.microvm = {
    url = "github:astro/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      index = 1;
      mac = "00:00:00:00:00:01";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.net-vm;
        net-vm = self.nixosConfigurations.net-vm.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        net-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import /../net-config.nix { inherit lib index mac; })
            {
              networking.hostName = "basic-vm";

              users.groups.nx = {};
              users.users.nx = {
                isNormalUser = true;
                group = "nx";
                extraGroups = [ "wheel" ];
              };
              services.getty.autologinUser = "nx";
              security.sudo = {
                enable = true;
                wheelNeedsPassword = false;
              };

              environment.systemPackages = with pkgs; [
                btop
              ];
              system.stateVersion = "25.11";
            }
          ];
        };
      };
    };
}
