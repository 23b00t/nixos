{
  pkgs,
  lib,
  inputs,
  hostname,
  config,
  ...
}:
let
  kittyConf = import ./kitty/kitty.nix;
  myGithubAgent = import ./vm-management/github-agent.nix { inherit pkgs; };
in
{
  imports = [
    ./zsh.nix
    ./vim.nix
    ./yazi.nix
    (import ./hypr/waybar.nix { inherit config lib pkgs; })
    (import ./hypr/rofi.nix { inherit config lib pkgs; })
    (import ./hypr/hypr.nix { inherit config pkgs hostname; })
    (import ./hypr/xdg-gtk-qt.nix { inherit config pkgs; })
    ./ssh.nix
    ./vm-management/vm-run.nix
    ./vm-management/desktop-entries.nix
    ./vm-management/vm-connect.nix
  ];

  home = {
    username = "nx";
    homeDirectory = "/home/nx";
    sessionVariables.LANG = "en_US.UTF-8";
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    (writeShellScriptBin "nvim" ''
      #!${pkgs.bash}/bin/bash
      # This script acts as a wrapper to redirect `nvim` calls to the nvim MicroVM.
      # It passes all arguments it receives to the nvim_vm script.
      exec zsh -c 'source /home/nx/nixos-config/home/resources/nvim.zsh; nvim_vm "$@"' _ "$@"
    '')
    oh-my-posh
    fastfetch
    # misc
    file
    tree

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    btop # replacement of htop/nmon
    iotop # io monitoring

    # system call monitoring
    # strace # system call monitoring
    # ltrace # library call monitoring
    lsof # list open files
    # system tools
    sysstat
    pciutils # lspci
    usbutils # lsusb
    nerd-fonts.fira-code
    chromium
    bibata-cursors
    (import ./vm-management/remote-zellij.nix { inherit pkgs; })
    (import ./vm-management/backup.nix { inherit pkgs lib inputs; })
    (import ./vm-management/vmcopy-keys.nix { inherit pkgs; })
    myGithubAgent
    # GitHub agent is now also started automatically as user service below.
  ];

  home.file.".config/kitty/kitty.conf" = {
    text = kittyConf;
    force = true;
  };
  home.file.".config/kitty/current-theme.conf".source = ./kitty/current-theme.conf;
  home.file.".config/kitty/startup".source = ./kitty/startup;

  # zellij
  home.file.".config/zellij".source = ./zellij;

  # oh-my-posh theme
  home.file.".cache/oh-my-posh/themes/slimfat.omp.json".source = ./resources/slimfat.omp.json;

  home.sessionVariables = {
    SSH_AUTH_SOCK = "$HOME/.ssh/agent/github.sock";
  };

  systemd.user.services.github-agent = {
    Unit = {
      Description = "GitHub SSH Agent bootstrap";
      After = [ "default.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${myGithubAgent}/bin/github-agent";
      Environment = "HOME=%h";
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.stateVersion = "26.05";
}
