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
          IdentityAgent = "none";
          RemoteForward = "4713 localhost:4713";
        };
      };
      "irc-vm 10.0.0.11" = {
        user = "user";
        identityFile = "~/.ssh/irc-vm";
        identitiesOnly = true;
        extraOptions = {
          IdentityAgent = "none";
        };
      };
    };
  };

  systemd.user.services.ssh-agent = {
    Unit = {
      Description = "SSH key agent";
    };
    Service = {
      Type = "forking";
      Environment = "SSH_AUTH_SOCK=%t/ssh-agent.socket";
      ExecStart = "${pkgs.openssh}/bin/ssh-agent -a %t/ssh-agent.socket";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.ssh-add = {
    Unit = {
      Description = "Add SSH keys to agent";
      After = [ "ssh-agent.service" ];
    };
    Service = {
      Type = "oneshot";
      Environment = "SSH_AUTH_SOCK=%t/ssh-agent.socket";
      ExecStart = ''
        ${pkgs.openssh}/bin/ssh-add \
          %h/.ssh/nvim-vm \
          %h/.ssh/chat-vm \
          %h/.ssh/office-vm \
          %h/.ssh/irc-vm
      '';
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
