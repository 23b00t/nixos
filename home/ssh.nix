{ lib, inputs, ... }:
let
  vmRegistry = import ../vms/registry.nix;

  hosts = vmRegistry.vms;

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
      identityFile = "~/.ssh/${h.sshKeyName}";
      identitiesOnly = true;
      forwardAgent = true;
    };
  };

  matchBlocks = builtins.foldl' (acc: h: acc // mkMatchBlock h) {
    "*" = {
      addKeysToAgent = "yes";
    };
  } hosts;

in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = hostStrings;
    inherit matchBlocks;
  };
}
