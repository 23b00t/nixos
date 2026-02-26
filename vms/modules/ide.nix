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
      description = "Target user for IDE-related configuration";
    };

    lazyvimRepo = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/23b00t/lazyvim.git";
      description = "Git URL of the LazyVim config repository";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gnupg
      pinentry-curses
      git
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

      ripgrep
      fzf

      (pkgs.writeShellScriptBin "lazygit" ''
        export GPG_TTY=$(tty)
        ${pkgs.gnupg}/bin/gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
        exec ${pkgs.lazygit}/bin/lazygit "$@"
      '')
    ];

    # für statisch gelinkte Binaries in nvim
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

    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/.config 0755 ${cfg.user} users -"
      "L+ /home/${cfg.user}/.gnupg/gpg-agent.conf - - - - /etc/gpg-agent.conf"
    ];

    environment.etc."gpg-agent.conf".text = ''
      pinentry-program /run/current-system/sw/bin/pinentry-tty
    '';

    systemd.services.ide-lazyvim-config = {
      description = "Clone/update LazyVim config into ~/.config/nvim";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = "users";
        ExecStart = pkgs.runtimeShell + ''
          -c '
            set -e
            NVIM_DIR="/home/${cfg.user}/.config/nvim"
            REPO_URL="${cfg.lazyvimRepo}"

            if [ ! -d "$NVIM_DIR/.git" ]; then
              mkdir -p "$(dirname "$NVIM_DIR")"
              git clone "$REPO_URL" "$NVIM_DIR"
            else
              cd "$NVIM_DIR"
              git pull --ff-only || true
            fi
          '
        '';
      };
    };
  };
}
