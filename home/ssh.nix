{
  lib,
  pkgs,
  inputs,
  osConfig ? { },
  ...
}:
let
  vmRegistry = import ../vms/registry.nix;
  # Xen guests dom0 reaches over vchan (nox-relay, stage B): ssh goes through
  # the relay socket instead of the admin network; also for connections by IP
  relayed = osConfig.services.nox-relay.host.guests or { };
  relaySsh = name: (relayed.${name}.listen or { }).ssh.path or null;

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
    }
    // lib.optionalAttrs (relaySsh h.name != null) {
      ProxyCommand = "${pkgs.socat}/bin/socat - UNIX-CONNECT:${relaySsh h.name}";
    };
  };

  settings = builtins.foldl' (acc: h: acc // mkSettingsBlock h) {
    # Goes to dom0's own agent (SSH_AUTH_SOCK), never to the GitHub agent
    # that VMs get (home.nix)
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
