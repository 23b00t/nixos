{
  description = "Electron wrapper flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system}.electron-wrapper = pkgs.callPackage ./electron-wrapper.nix {};
      defaultPackage.${system} = self.packages.${system}.electron-wrapper;
    };
}
