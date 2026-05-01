{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  githubAgentHosts = builtins.filter (h: h.allowGitHubAgent or false) vmRegistry.vms;
  githubAgentBin = import ./github-agent.nix { inherit pkgs; };
  vmUser = "user";
  localGitHubAgentSocket = "%h/.ssh/agent/github.sock";
  remoteGitHubAgentSocket = "/tmp/ssh-github-agent.sock";
  sshVmOptions = builtins.concatStringsSep " " [
    "-o BatchMode=yes"
    "-o ExitOnForwardFailure=yes"
    "-o ServerAliveInterval=30"
    "-o ServerAliveCountMax=3"
    "-o ControlMaster=no"
    "-o IdentitiesOnly=yes"
    "-o StrictHostKeyChecking=no"
    "-o UserKnownHostsFile=/dev/null"
    "-o IdentityAgent=none"
    "-o ForwardAgent=no"
    "-o StreamLocalBindUnlink=yes"
    "-o ConnectTimeout=5"
  ];
in
{
  systemd.user.services = {
    github-agent = {
      Unit = {
        Description = "Ensure dedicated GitHub SSH agent is running";
        After = [ "default.target" ];
        Wants = [ "default.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${githubAgentBin}/bin/github-agent";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  }
  // builtins.listToAttrs (
    map (
      vm: {
        name = "vm-github-agent-forward@${vm.name}";
        value = {
          Unit = {
            Description = "Persistent GitHub agent remote-forward tunnel for ${vm.name}-vm";
            After = [ "default.target" "github-agent.service" ];
            Wants = [ "default.target" "github-agent.service" ];
          };
          Service = {
            Type = "simple";
            Restart = "always";
            RestartSec = 5;
            ExecStartPre = "${pkgs.coreutils}/bin/test -S ${localGitHubAgentSocket}";
            ExecStart = "${pkgs.openssh}/bin/ssh -N ${sshVmOptions} -i %h/.ssh/${vm.name}-vm -R ${remoteGitHubAgentSocket}:${localGitHubAgentSocket} ${vmUser}@${vm.ip}";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      }
    ) githubAgentHosts
  );
}
