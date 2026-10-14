{
  pkgs,
  lib,
  inputs,
  vmRegistry,
  ...
}:
let
  kittyConf = import ./kitty/kitty.nix;
  myGithubAgent = import ./vm-management/github-agent.nix { inherit pkgs; };
in
{
  imports = [
    ./vim.nix
    ./desktop/waybar.nix
    ./desktop/rofi.nix
    ./desktop/niri.nix
    ./desktop/xdg-gtk-qt.nix
    ./ssh.nix
    ./vm-management/vm-run.nix
    ./vm-management/vm-gui.nix
    ./vm-management/desktop-entries.nix
    ./vm-management/vm-dbus-forward.nix
    ./vm-management/github-agent-forward.nix
  ];

  home = {
    username = "nx";
    homeDirectory = "/home/nx";
    sessionVariables.LANG = "en_US.UTF-8";
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
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
    # chromium
    bibata-cursors
    (import ./vm-management/remote-zellij.nix { inherit pkgs; })
    (import ./vm-management/backup.nix {
      inherit
        pkgs
        lib
        inputs
        vmRegistry
        ;
    })
    (import ./vm-management/vmcopy-keys.nix { inherit pkgs vmRegistry; })
    (import ./vm-management/manage-vms.nix { inherit pkgs vmRegistry; })
    (import ./vm-management/create-vm.nix { inherit pkgs; })
    (import ./vm-management/explorer.nix { inherit pkgs vmRegistry; })
    myGithubAgent
    # GitHub agent is now also started automatically as user service below.
  ];

  # Slim login shell for dom0 (replaces zsh, 2026-10-14)
  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      edit = "sudo -e";
      sc = "systemctl";
      kk = "kitty @ kitten";
      tm = "vm-run -c coding termusic";
      kali = "vm-run -c kali distrobox enter kali";
    };
    historySize = 10000;
    historyControl = [
      "erasedups"
      "ignoredups"
      "ignorespace"
    ];
    historyIgnore = [
      "rm *"
      "cp *"
    ];
    initExtra = ''
      PS1='\[\e[1;34m\]\u@\h\[\e[0m\] \[\e[1;32m\]\w\[\e[0m\] \$ '

      ms() { systemctl start microvm@"$1".service; }
      mst() { systemctl stop microvm@"$1".service; }
      mr() { systemctl restart microvm@"$1".service; }
    '';
  };

  home.file.".config/kitty/kitty.conf" = {
    text = kittyConf;
    force = true;
  };
  home.file.".config/kitty/current-theme.conf".source = ./kitty/current-theme.conf;
  home.file.".config/kitty/startup".source = ./kitty/startup;

  # zellij
  home.file.".config/zellij".source = ./zellij;

  # SSH_AUTH_SOCK stays dom0's own agent (programs.ssh.startAgent). The
  # GitHub agent (~/.ssh/agent/github.sock) is handed to VMs and must only
  # ever hold the GitHub key: github.com uses it via IdentityAgent (ssh.nix),
  # git commit signing via gpg.ssh.program (machines/hp/dev-access.nix).

  home.stateVersion = "26.05";
}
