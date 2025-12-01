{
programs.ssh = {
  enable = true;
  enableDefaultConfig = false;
  extraConfig = ''
    Host chat-vm 10.0.0.2
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
      addKeysToAgent = "yes";
    };
    "nvim-vm 10.0.0.1" = {
      user = "user";
      identityFile = "~/.ssh/nvim-vm";
    };
    "chat-vm 10.0.0.2" = {
      user = "user";
      identityFile = "~/.ssh/chat-vm";
    };
    "irc-vm 10.0.0.5" = {
      user = "irc";
      identityFile = "~/.ssh/id_irc";
    };
  };
};
}
