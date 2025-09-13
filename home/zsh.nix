{ config, pkgs, ...}: {
  # zsh
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      edit = "sudo -e";
      update = "sudo nixos-rebuild switch";
      sc = "systemctl";
      cmd = "eval $(fzf < ~/cmds)";
      pcmd = "cmd=$(fzf < ~/cmds); vared -p '> ' -c cmd; eval '$cmd'";
      containers = "nix develop '/home/nx/nixos-config#containers'";
      n = "nvim";
      dc = "docker compose";
      kk = "kitty @ kitten";
    };

    history.size = 10000;
    history.ignoreAllDups = true;
    history.path = "$HOME/.zsh_history";
    history.ignorePatterns = ["rm *" "cp *"];

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
        "ohmyzsh/ohmyzsh path:plugins/git"
      ];
    };
	initContent = ''
    # Oh My Posh: OMP_CONFIG (aus DevShell/Alias) > POSH_THEME > Default (1_shell)
    # _omp_default="$HOME/.cache/oh-my-posh/themes/1_shell.omp.json"
    # _omp_cfg="''${OMP_CONFIG:-''${POSH_THEME:-$_omp_default}}"

    if command -v oh-my-posh >/dev/null 2>&1; then
      eval "$(oh-my-posh init zsh --config "$HOME/.cache/oh-my-posh/themes/1_shell.omp.json")"
    fi
    # unset _omp_cfg _omp_default

    # GitHub Copilot CLI Aliases
    if command -v ${pkgs.gh}/bin/gh >/dev/null 2>&1; then
      eval "$(${pkgs.gh}/bin/gh copilot alias -- zsh)"
    fi
	'';
  };
}
