{
  pkgs,
  lib,
  inputs,
  vmRegistry,
  hostname,
  ...
}:
let
  theme = import (inputs.nox.lib.home + "/desktop/theme.nix") { inherit lib; };
  myGithubAgent = import (inputs.nox.lib.home + "/vm-management/github-agent.nix") { inherit pkgs; };
in
{
  imports = [
    ./vim.nix
    (inputs.nox.lib.home + "/desktop/waybar.nix")
    (inputs.nox.lib.home + "/desktop/rofi.nix")
    (inputs.nox.lib.home + "/desktop/niri.nix")
    (inputs.nox.lib.home + "/desktop/xdg-gtk-qt.nix")
    ./ssh.nix
    (inputs.nox.lib.home + "/vm-management/vm-run.nix")
    (inputs.nox.lib.home + "/vm-management/vm-gui.nix")
    (inputs.nox.lib.home + "/vm-management/vm-doctor.nix")
    (inputs.nox.lib.home + "/vm-management/vm-backup.nix")
    (inputs.nox.lib.home + "/vm-management/vm-rollback.nix")
    (inputs.nox.lib.home + "/vm-management/desktop-entries.nix")
    (inputs.nox.lib.home + "/vm-management/github-agent-forward.nix")
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

    btop # replacement of htop/nmon
    iotop # io monitoring

    # system call monitoring
    # strace # system call monitoring
    # ltrace # library call monitoring
    lsof # list open files
    # system tools
    pciutils # lspci
    usbutils # lsusb
    nerd-fonts.fira-code
    # chromium
    bibata-cursors
    (import (inputs.nox.lib.home + "/vm-management/manage-vms.nix") { inherit pkgs vmRegistry; })
    # nox disp: start the ad-hoc disposable (empty on every start, registry
    # `disposable`) and open a program in it, foot by default; `nox stop
    # disp` throws it away
    (pkgs.writeShellScriptBin "vm-disp" ''
      set -eu
      [ $# -gt 0 ] || set -- foot
      manage-vms start disp
      # A fresh disp needs its volumes made and a boot: wait for its relay
      for _ in $(seq 240); do
        [ -e /run/nox-relay/disp.ready ] && break
        sleep 0.5
      done
      exec vm-run disp "$@"
    '')
    (import (inputs.nox.lib.home + "/vm-management/create-vm.nix") { inherit pkgs; })
    (import (inputs.nox.lib.home + "/vm-management/explorer.nix") { inherit pkgs vmRegistry; })
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
      # ble.sh: suggestions from the history as shadow text (like
      # zsh-autosuggestions), accept with Right/End
      source ${pkgs.blesh}/share/blesh/ble.sh --noattach

      PS1='\[\e[1;34m\]\u@\h\[\e[0m\] \[\e[1;32m\]\w\[\e[0m\] \$ '

      # VMs by their full names, via manage-vms (sudo NOPASSWD for microvm@
      # units; a (re)started VM gets its tray apps again, vm-tray)
      vmunit() {
        [ $# -ge 2 ] && [ "$2" != help ] || { echo "usage: ms|mst|mr <vm>..." >&2; return 2; }
        manage-vms "$@"
      }
      ms() { vmunit start "$@"; }
      mst() { vmunit stop "$@"; }
      mr() { vmunit restart "$@"; }

      # Pick a command from the list (fzf) and run it; pcmd: edit it first
      cmd() { local c; c=$(fzf < ${./resources/cmds}) && eval "$c"; }
      pcmd() { local c; c=$(fzf < ${./resources/cmds}) && read -r -e -i "$c" -p '> ' c && eval "$c"; }

      # nox xen|nix|root: the line that ran lands in this shell's history
      # (nox writes it to NOX_HISTORY_OUT)
      nox() {
        local f rc
        f=$(mktemp) || return
        NOX_HISTORY_OUT=$f command nox "$@"
        rc=$?
        [ -s "$f" ] && history -s "$(<"$f")"
        rm -f "$f"
        return $rc
      }

      [[ ''${BLE_VERSION-} ]] && ble-attach
    '';
  };

  # Terminal in dom0 and, over wprs, in the VMs (vms/modules/wprs.nix)
  programs.foot = {
    enable = true;
    # locked-title: programs in dom0's terminal (also SSH sessions into VMs)
    # can't set a title like "[vault] …" and get that VM's border in niri
    settings = lib.recursiveUpdate theme.foot { main.locked-title = "yes"; };
  };

  # zellij in dom0 only on the hp (machines/hp/configuration.nix)
  home.file.".config/zellij" = lib.mkIf (hostname == "hp") { source = ./zellij; };

  # SSH_AUTH_SOCK stays dom0's own agent (programs.ssh.startAgent). The
  # GitHub agent (~/.ssh/agent/github.sock) is handed to VMs and must only
  # ever hold the GitHub key: github.com uses it via IdentityAgent (ssh.nix),
  # git commit signing via gpg.ssh.program (machines/hp/dev-access.nix).

  home.stateVersion = "26.05";
}
