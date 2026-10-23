# The user's dom0 shell and tools (was home-manager, home/home.nix and
# home/vim.nix; NoX modules step 2): packages, bash, vim, zellij on the hp.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cmds = ../home/resources/cmds;
in
{
  users.users.nx.packages = with pkgs; [
    fastfetch
    # misc
    file
    tree

    btop # replacement of htop/nmon
    iotop # io monitoring

    lsof # list open files
    # system tools
    pciutils # lspci
    usbutils # lsusb
    nerd-fonts.fira-code
    bibata-cursors
  ];

  # Slim login shell for dom0 (replaces zsh, 2026-10-14)
  programs.bash = {
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      edit = "sudo -e";
      sc = "systemctl";
      kali = "vm-run -c kali distrobox enter kali";
    };
    promptInit = ''
      PS1='\[\e[1;34m\]\u@\h\[\e[0m\] \[\e[1;32m\]\w\[\e[0m\] \$ '
    '';
    interactiveShellInit = lib.mkMerge [
      ''
        # History and shell options as home-manager set them
        HISTSIZE=10000
        HISTFILESIZE=100000
        HISTCONTROL=erasedups:ignoredups:ignorespace
        HISTIGNORE='rm *:cp *'
        shopt -s histappend checkwinsize extglob globstar checkjobs

        # ble.sh: suggestions from the history as shadow text (like
        # zsh-autosuggestions), accept with Right/End
        source ${pkgs.blesh}/share/blesh/ble.sh --noattach

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
        cmd() { local c; c=$(fzf < ${cmds}) && eval "$c"; }
        pcmd() { local c; c=$(fzf < ${cmds}) && read -r -e -i "$c" -p '> ' c && eval "$c"; }

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
      ''
      (lib.mkAfter ''
        [[ ''${BLE_VERSION-} ]] && ble-attach
      '')
    ];
  };

  # vim with the user's vimrc (dom0's $EDITOR, programs.vim in NoX's base)
  programs.vim.package = pkgs.vim-full.customize {
    name = "vim";
    vimrcConfig = {
      customRC = ''
        set expandtab
        set number

        " Deactivate swap files
        set noswapfile

        " Use system clipboard (Wayland)
        set clipboard=unnamedplus

        " Keep visual selection after indenting
        vnoremap < <gv
        vnoremap > >gv
      '';
      packages.user.start = [ pkgs.vimPlugins.vim-sensible ];
    };
  };

  # zellij in dom0 only on the hp (machines/hp/configuration.nix). Without
  # ZELLIJ_CONFIG_DIR zellij writes its default config to ~/.config/zellij
  # on the first start, which then shadows /etc/zellij
  environment = lib.mkIf (config.networking.hostName == "hp") {
    etc."zellij".source = ../home/zellij;
    variables.ZELLIJ_CONFIG_DIR = "/etc/zellij";
  };

  # SSH_AUTH_SOCK stays dom0's own agent (programs.ssh.startAgent). The
  # GitHub agent (~/.ssh/agent/github.sock) is handed to VMs and must only
  # ever hold the GitHub key: github.com uses it via IdentityAgent (NoX
  # dom0/tools/ssh.nix), git commit signing via gpg.ssh.program
  # (machines/hp/dev-access.nix).
}
