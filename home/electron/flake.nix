# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.awrit-fhs = nixpkgs.legacyPackages.x86_64-linux.buildFHSEnv {
      name = "awrit-fhs";
      runScript = "bash";
      targetPkgs = pkgs: [
        pkgs.electron
        # weitere Libs
      ];
    };
  };
}
