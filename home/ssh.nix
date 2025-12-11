{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      Host chat-vm 10.0.0.2
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
      Host chat-vm 10.0.0.3
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
      Host irc-vm 10.0.0.5
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
      Host nvim-vm 10.0.0.1
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    '';
    matchBlocks = {
      "*" = {
        #   addKeysToAgent = "yes";
      };
      "nvim-vm 10.0.0.1" = {
        user = "user";
        identityFile = "~/.ssh/nvim-vm";
        identitiesOnly = true;
        extraOptions = {
          IdentityAgent = "none";
        };
      };
      "chat-vm 10.0.0.2" = {
        user = "user";
        identityFile = "~/.ssh/chat-vm";
        identitiesOnly = true;
        extraOptions = {
          IdentityAgent = "none";
        };
      };
      "office-vm 10.0.0.3" = {
        user = "user";
        identityFile = "~/.ssh/office-vm";
        identitiesOnly = true;
        extraOptions = {
          RemoteForward = "4713 localhost:4713";
          IdentityAgent = "none";
        };
      };
      "irc-vm 10.0.0.11" = {
        user = "irc";
        identityFile = "~/.ssh/irc-vm";
        identitiesOnly = true;
        extraOptions = {
          IdentityAgent = "none";
        };
      };
    };
  };
}
