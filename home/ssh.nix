{ lib, inputs, ... }:
let
  vmRegistry = import ../vms/registry.nix;

  hosts = vmRegistry.vms;

  hostStrings = builtins.concatStringsSep "\n" (map (h:
    "Host ${h.name}-vm ${h.ip}\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null"
  ) hosts);

  mkMatchBlock = h: {
    "${h.name}-vm ${h.ip}" =
      {
        user = "user";
        identityFile = "~/.ssh/${h.sshKeyName}";
        identitiesOnly = true;
        forwardAgent = true;
      }
      // (if h.extraSSH or {} != {} then { extraOptions = h.extraSSH; } else {});
  };

  matchBlocks = builtins.foldl' (acc: h: acc // mkMatchBlock h) {
    "*" = { addKeysToAgent = "yes"; };
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

