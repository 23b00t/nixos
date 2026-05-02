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
      cmd = "eval $(fzf < ~/nixos-config/home/resources/cmds)";
      pcmd = "cmd=$(fzf < ~/nixos-config/home/resources/cmds); vared -p '> ' -c cmd; eval '$cmd'";
      kk = "kitty @ kitten";
      n = "nvim_vm";
      tm = "vm-run -c -e '-R 4713:localhost:4713' music termusic";
      kali = "vm-run -c kali distrobox enter kali";
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
      ];
    };
    initContent = ''
      if command -v oh-my-posh >/dev/null 2>&1; then
        eval "$(oh-my-posh init zsh --config "$HOME/.cache/oh-my-posh/themes/slimfat.omp.json")"
      fi
      # Load custom functions
      [ -f "$HOME/nixos-config/home/resources/nvim.zsh" ] && source "$HOME/nixos-config/home/resources/nvim.zsh"

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
