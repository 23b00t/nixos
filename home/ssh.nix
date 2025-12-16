{ pkgs, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      Host nvim-vm 10.0.0.1
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
      Host chat-vm 10.0.0.2
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
      Host office-vm 10.0.0.3
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
      Host irc-vm 10.0.0.11
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    '';
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
      };
      "nvim-vm 10.0.0.1" = {
        user = "user";
        identityFile = "~/.ssh/nvim-vm";
        identitiesOnly = true;
        forwardAgent = true;
      };
      "chat-vm 10.0.0.2" = {
        user = "user";
        identityFile = "~/.ssh/chat-vm";
        identitiesOnly = true;
        forwardAgent = true;
      };
      "office-vm 10.0.0.3" = {
        user = "user";
        identityFile = "~/.ssh/office-vm";
        identitiesOnly = true;
        forwardAgent = true;
        extraOptions = {
          RemoteForward = "4713 localhost:4713";
        };
      };
      "irc-vm 10.0.0.11" = {
        user = "user";
        identityFile = "~/.ssh/irc-vm";
        identitiesOnly = true;
        forwardAgent = true;
      };
    };
  };
}
