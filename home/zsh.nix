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
      update = "nix flake update && sudo nixos-rebuild switch";
      rebuild = "sudo nixos-rebuild switch";
      sc = "systemctl";
      ddate = "nix run 'nixpkgs#ddate'";
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
        "zap-zsh/vim"
        "zap-zsh/sudo"
        "wintermi/zsh-oh-my-posh"
        "kutsan/zsh-system-clipboard"
        "ohmyzsh/ohmyzsh path:plugins/git"
      ];
    };
	initContent = ''
    if command -v oh-my-posh >/dev/null 2>&1; then
      eval "$(oh-my-posh init zsh --config "$HOME/.cache/oh-my-posh/themes/slimfat.omp.json")"
    fi
	'';
  };
}
