{
  description = "wprs package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    packages.x86_64-linux.default =
      pkgs.rustPlatform.buildRustPackage {
        pname = "wprs";
        version = "git";

        src = pkgs.fetchFromGitHub {
          owner = "wayland-transpositor";
          repo  = "wprs";
          rev   = "master";
          sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };

        cargoLock = {
          lockFile = ./Cargo.lock;
        };

        nativeBuildInputs = [
          pkgs.pkg-config
        ];

        buildInputs = [
          pkgs.libxkbcommon
          pkgs.wayland
          pkgs.xorg.xwayland
          pkgs.python3
          pkgs.python3Packages.psutil
          pkgs.openssh
        ];
      };
  };
}
