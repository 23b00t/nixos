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
      dev = "nix develop '/home/nx/nixos-config#dev' --command zsh";
      containers = "nix develop '/home/nx/nixos-config#containers'";
      n = "nvim";
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
		export POSH_THEME="$HOME/.cache/oh-my-posh/themes/1_shell.omp.json"
		eval "$(oh-my-posh init zsh --config $POSH_THEME)"

    # GitHub Copilot CLI Aliases
    if command -v ${pkgs.gh}/bin/gh >/dev/null 2>&1; then
      eval "$(${pkgs.gh}/bin/gh copilot alias -- zsh)"
    fi
	'';
  };
}
