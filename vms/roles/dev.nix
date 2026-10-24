# The user's additions to NoX's dev role (every dev VM): claude-code, git
# identity with SSH commit signing, the own LazyVim config. claude-code is
# unfree, so the dev store group is marked unfree (vms.nix).
{ lib, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.claude-code ];
  nox.unfree = [ "claude-code" ];

  programs.git.config = {
    user = {
      name = "Daniel Kipp";
      email = "daniel.kipp@gmail.com";
      signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIiMX73JzJQ1gk9fUyiiOgQYeH40DTkcD0NKtzpySORN daniel.kipp@gmail.com";
    };
    gpg.format = "ssh";
    commit.gpgsign = true;
  };

  # nvim pulls it over SSH (vms/nvim.nix)
  services.ide.lazyvimRepo = lib.mkDefault "https://github.com/23b00t/lazyvim.git";
}
