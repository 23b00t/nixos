{
  lib,
  pkgs,
  osConfig ? { },
  vmRegistry,
  ...
}:
let
  # Xen guests dom0 reaches over vchan (nox-relay, stage B): ssh goes through
  # the relay socket instead of the admin network; also for connections by IP
  relayed = osConfig.services.nox-relay.host.guests or { };
  relaySsh = name: (relayed.${name}.listen or { }).ssh.path or null;

  # Image domains (Whonix) have no admin link: SSH only through the relay
  hosts = vmRegistry.vms ++ vmRegistry.imageDomains;
  imageDomainNames = map (d: d.name) vmRegistry.imageDomains;
  githubAgentSocket = "%d/.ssh/agent/github.sock";

  # Extra options from the registry (extraSSH, globalExtraSSH), if any
  hostStrings = builtins.concatStringsSep "\n" (
    lib.concatMap (
      h:
      let
        allExtra = (h.extraSSH or [ ]) ++ (vmRegistry.globalExtraSSH or [ ]);
      in
      lib.optional (allExtra != [ ]) ("Host ${h.name}-vm\n  " + builtins.concatStringsSep "\n  " allExtra)
    ) hosts
  );

  # `ssh <name>-vm`, `ssh <name>`, `ssh <short>` and the registry IP all
  # reach the same guest
  mkSettingsBlock = h: {
    "${lib.concatStringsSep " " (
      lib.unique (
        [
          "${h.name}-vm"
          h.name
        ]
        ++ lib.optional ((h.short or null) != null) h.short
        ++ [ h.ip ]
      )
    )}" =
    {
      User = "user";
      IdentityFile = "~/.ssh/${h.name}-vm";
      IdentitiesOnly = true;
      # Host keys differ per machine (generated in the guests): remember
      # each on first use, then verify. One known_hosts entry per guest
      # for all its aliases
      HostKeyAlias = "${h.name}-vm";
      StrictHostKeyChecking = "accept-new";
    }
    // lib.optionalAttrs (relaySsh h.name != null) {
      ProxyCommand = "${pkgs.socat}/bin/socat - UNIX-CONNECT:${relaySsh h.name}";
    }
    # Debian images (Whonix) lack kitty's terminfo
    // lib.optionalAttrs (lib.elem h.name imageDomainNames) {
      SetEnv.TERM = "xterm-256color";
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
