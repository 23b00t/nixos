{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ide;
in
{
  options.services.ide = {
    enable = lib.mkEnableOption "IDE stack (nvim, git, etc.)";

    user = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Default target user";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gnupg
      pinentry-curses
      gh
      github-copilot-cli
      openssl

      python3
      fd
      zip
      xz
      unzip
      p7zip

      gcc
      gnumake
      rustc
      cargo
      rust-analyzer
      watchexec
      statix
      tree-sitter
      vectorcode
      nodejs
      nodePackages.npm
      watchman
      icu

      zellij
      antidote
      ripgrep
      fzf
      oh-my-posh
      eza
      zoxide

      (writeShellScriptBin "lazygit" ''
        export GPG_TTY=$(tty)
        ${gnupg}/bin/gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
        exec ${lazygit}/bin/lazygit "$@"
      '')
    ];

    # for static linked binaries in nvim
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [ icu ];

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      withNodeJs = true;
      withPython3 = true;
    };

    environment.variables.EDITOR = "nvim";
    environment.variables.VISUAL = "nvim";

    nixpkgs.config.allowUnfree = true;
    networking.hostName = "nvim-vm";

    programs.zsh.enable = true;
    users.defaultUserShell = pkgs.zsh;
    users.users.user.shell = pkgs.zsh;

    programs.zsh = {
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

      shellAliases = {
        ll = "ls -l";
        la = "ls -la";
        sc = "systemctl";
        n = "nvim";
      };

      histSize = 10000;
      histFile = "$HOME/.zsh_history";

      shellInit = ''
        if [[ $- != *i* ]]; then
          return
        fi
        export HISTIGNORE="rm *:cp *"
        setopt HIST_IGNORE_ALL_DUPS
        export GPG_TTY=$(tty)

        # Use antidote plugin manager
        export ANTIDOTE_HOME="$HOME/.cache/antidote"
        mkdir -p "$ANTIDOTE_HOME"
        source ${pkgs.antidote}/share/antidote/antidote.zsh

        antidote bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.zsh
        antidote load

        if command -v oh-my-posh >/dev/null 2>&1; then
          eval "$(oh-my-posh init zsh --config "$HOME/.cache/oh-my-posh/themes/montys.omp.json")"
        fi

        # Solve SSL cert issue
        export SSL_CERT_DIR=/etc/ssl/certs
        export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
      '';
    };

    environment.etc = {
      "zsh_plugins.txt".text = ''
        zsh-users/zsh-autosuggestions
        zap-zsh/supercharge
        zsh-users/zsh-syntax-highlighting
        atoftegaard-git/zsh-omz-autocomplete
        MichaelAquilina/zsh-you-should-use
        zap-zsh/magic-enter
        chivalryq/git-alias
        zap-zsh/vim
        zap-zsh/sudo
        wintermi/zsh-oh-my-posh
      '';

      "gpg-agent.conf".text = ''
        pinentry-program /run/current-system/sw/bin/pinentry-tty
      '';
    };
    systemd.tmpfiles.rules = [
      # Symlink /etc/zshrc nach /home/user/.zshrc, falls nicht vorhanden
      "L+ /home/user/.zshrc - - - - /etc/zshrc"
      "L+ /home/user/.zsh_plugins.txt - - - - /etc/zsh_plugins.txt"
      "L+ /home/user/.gnupg/gpg-agent.conf - - - - /etc/gpg-agent.conf"
      "d /home/${cfg.user}/.config 0755 ${cfg.user} users -"
    ];
  };
}
