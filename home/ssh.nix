{ lib, inputs, ... }:
let
  vmRegistry = import ../vms/registry.nix;

  hosts = vmRegistry.vms;
  githubAgentHosts = builtins.filter (h: h.allowGitHubAgent or false) hosts;
  githubAgentSocket = "%d/.ssh/agent/github.sock";

  hostStrings = builtins.concatStringsSep "\n" (
    map (
      h:
      let
        allExtra = (h.extraSSH or [ ]) ++ (vmRegistry.globalExtraSSH or [ ]);
        extra = if allExtra != [ ] then builtins.concatStringsSep "\n  " allExtra else "";
      in
      "Host ${h.name}-vm ${h.ip}\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null"
      + (if extra != "" then "\n  " + extra else "")
    ) hosts
  );

  mkMatchBlock = h: {
    "${h.name}-vm ${h.ip}" = {
      user = "user";
      identityFile = "~/.ssh/${h.name}-vm";
      identitiesOnly = true;
    };
  };

  matchBlocks = builtins.foldl' (acc: h: acc // mkMatchBlock h) {
    "*" = {
      addKeysToAgent = "yes";
    };
    "github.com" = {
      identityAgent = githubAgentSocket;
      identitiesOnly = true;
    };
  } hosts;

in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = hostStrings + "\n"
      + builtins.concatStringsSep "\n" (
        map (h: ''
          Host ${h.name}-vm ${h.ip}
            IdentityAgent none
            ForwardAgent no
            ExitOnForwardFailure yes
            RemoteForward /tmp/ssh-github-agent.sock ${githubAgentSocket}
        '') githubAgentHosts
      );
    inherit matchBlocks;
  };
}
