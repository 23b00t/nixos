# The user's additions to NoX's dev role (every dev VM): claude-code. Unfree,
# so the dev store group is marked unfree (vms.nix).
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.claude-code ];
  nox.unfree = [ "claude-code" ];
}
