# Guest side of nox-relay (v2.8.4, NoX flake input): sockets from dom0 over a
# vchan instead of SSH forwards. Xen VMs only. First service: the GitHub agent
# (registry `allowGitHubAgent`), at the path the SSH forward used.
{
  lib,
  config,
  inputs,
  ...
}:
let
  vmRegistry = import ../registry.nix;
  vmName = lib.removeSuffix "-vm" (config.networking.hostName or "");
  githubAgent = (vmRegistry.byName.${vmName} or { }).allowGitHubAgent or false;
in
{
  imports = [ inputs.nox.nixosModules.relay ];

  config = lib.mkIf (config.microvm.hypervisor == "xen" && githubAgent) {
    services.nox-relay.guest = {
      enable = true;
      # uid/gid of `user` in the VMs
      listen.github-agent = {
        path = "/tmp/ssh-github-agent.sock";
        owner = "1000:100";
      };
    };
  };
}
