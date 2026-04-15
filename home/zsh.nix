{ pkgs, config, ... }:
{
  # zsh
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      edit = "sudo -e";
      update = "nix flake update && sudo nixos-rebuild switch";
      rebuild = "sudo nixos-rebuild switch";
      sc = "systemctl";
      cmd = "eval $(fzf < ~/nixos-config/home/cmds)";
      pcmd = "cmd=$(fzf < ~/nixos-config/home/cmds); vared -p '> ' -c cmd; eval '$cmd'";
      containers = "nix develop '/home/nx/nixos-config#containers'";
      kk = "kitty @ kitten";
      # ddate = "nix run 'nixpkgs#ddate'";
      countdown = "$HOME/nixos-config/home/scripts/countdown.sh";
      n = "nvim_vm";
      tm = "vm-run -c music termusic";
      oo = "remmina --disable-toolbar -c ~/.local/share/remmina/group_rdp_onlyoffice_10-0-0-9.remmina > /dev/null 2>&1 &";
    };

    history.size = 10000;
    history.ignoreAllDups = true;
    history.path = "$HOME/.zsh_history";
    history.ignorePatterns = [
      "rm *"
      "cp *"
    ];

    # Use antidote plugin manager
    antidote = {
      enable = true;
      plugins = [
        "zsh-users/zsh-autosuggestions"
        "zap-zsh/supercharge"
        "zsh-users/zsh-syntax-highlighting"
        "atoftegaard-git/zsh-omz-autocomplete"
        "MichaelAquilina/zsh-you-should-use"
        "zap-zsh/magic-enter"
        "chivalryq/git-alias"
        "zap-zsh/vim"
        "zap-zsh/sudo"
        "wintermi/zsh-oh-my-posh"
        "kutsan/zsh-system-clipboard"
        # "ohmyzsh/ohmyzsh path:plugins/git"
      ];
    };
    initContent = ''
          # Oh My Posh: OMP_CONFIG (aus DevShell/Alias) > POSH_THEME > Default (1_shell)
          # _omp_default="$HOME/.cache/oh-my-posh/themes/1_shell.omp.json"
          # _omp_cfg="''${OMP_CONFIG:-''${POSH_THEME:-$_omp_default}}"

          if command -v oh-my-posh >/dev/null 2>&1; then
            eval "$(oh-my-posh init zsh --config "$HOME/.cache/oh-my-posh/themes/slimfat.omp.json")"
          fi
          # unset _omp_cfg _omp_default

          # GitHub Copilot CLI Aliases
          # if command -v ${pkgs.gh}/bin/gh >/dev/null 2>&1; then
          #   eval "$(${pkgs.gh}/bin/gh copilot alias -- zsh)"
          # fi
          # if command -v zoxide >/dev/null 2>&1; then
          #   eval "$(zoxide init zsh)"
          # fi

          # Load custom functions
          [ -f "$HOME/nixos-config/home/paste_functions.zsh" ] && source "$HOME/nixos-config/home/paste_functions.zsh"
          [ -f "$HOME/nixos-config/home/nvim.zsh" ] && source "$HOME/nixos-config/home/nvim.zsh"

          ms() {
              systemctl start microvm@"$1".service
          }
          mst() {
              systemctl stop microvm@"$1".service
          }
          mr() {
              systemctl restart microvm@"$1".service
          }
      	'';
  };
}
