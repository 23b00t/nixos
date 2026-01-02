let
  hosts = [
    { name = "nvim-vm"; ip = "10.0.0.1"; }
    { name = "chat-vm"; ip = "10.0.0.2"; }
    { name = "test-vm"; ip = "10.0.0.3"; }
    { name = "music-vm"; ip = "10.0.0.4"; extraOptions = { RemoteForward = "4713 localhost:4713"; }; }
    { name = "net-vm"; ip = "10.0.0.5"; }
    { name = "net-private-vm"; ip = "10.0.0.6"; }
    { name = "wine-vm"; ip = "10.0.0.7"; }
    { name = "kali-vm"; ip = "10.0.0.8"; }
    { name = "office-vm"; ip = "10.0.0.9"; }
    { name = "vault-vm"; ip = "10.0.0.10"; }
    { name = "irc-vm"; ip = "10.0.0.11"; }
    { name = "steam-vm"; ip = "10.0.0.12"; }
  ];

  hostStrings = builtins.concatStringsSep "\n" (map (h:
    "Host ${h.name} ${h.ip}\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null"
  ) hosts);

  mkMatchBlock = h: {
    "${h.name} ${h.ip}" =
      {
        user = "user";
        identityFile = "~/.ssh/${h.name}";
        identitiesOnly = true;
        forwardAgent = true;
      }
      // (if h ? extraOptions then { extraOptions = h.extraOptions; } else {});
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
