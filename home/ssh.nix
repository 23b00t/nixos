{ lib, inputs, ... }:
let
  vmRegistry = import ../vms/registry.nix;

  hosts = vmRegistry.vms;
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

  mkSettingsBlock = h: {
    "${h.name}-vm ${h.ip}" = {
      User = "user";
      IdentityFile = "~/.ssh/${h.name}-vm";
      IdentitiesOnly = true;
    };
  };

  settings = builtins.foldl' (acc: h: acc // mkSettingsBlock h) {
    "*" = {
      AddKeysToAgent = "yes";
    };
    "github.com" = {
      IdentityAgent = githubAgentSocket;
      IdentitiesOnly = true;
    };
  } hosts;

in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = hostStrings;
    inherit settings;
  };
}
