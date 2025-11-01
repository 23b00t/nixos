{
  pkgs,
  ...
}:
{
  imports = [
    ./zsh.nix
  ];

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # yaziPkg
    zoxide
    oh-my-posh
    neofetch
    fastfetch

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # misc
    file
    tree

    nerd-fonts.droid-sans-mono

    lazygit
  ];

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
    extensions = with pkgs; [ gh-copilot ];
  };

  # git
  programs.git = {
    enable = true;
    userName = "Daniel Kipp";
    userEmail = "daniel.kipp@gmail.com";
    signing = {
      key = "937A32679620DC68";
      signByDefault = true;
    };

    extraConfig = {
      color = {
        branch = "auto";
        diff = "auto";
        interactive = "auto";
        status = "auto";
        ui = "auto";
      };

      "color \"branch\"" = {
        current = "green";
        remote = "yellow";
      };

      alias = {
        co = "checkout";
        st = "status -sb";
        br = "branch";
        ci = "commit";
        fo = "fetch origin";
        d = "!git --no-pager diff";
        dt = "difftool";
        stat = "!git --no-pager diff --stat";
        remoteSetHead = "remote set-head origin --auto";
        defaultBranch = "!git symbolic-ref refs/remotes/origin/HEAD | cut -d'/' -f4";
        sweep = "!git branch --merged $(git defaultBranch) | grep -E -v \" $(git defaultBranch)$\" | xargs -r git branch -d && git remote prune origin";
        lg = "log --graph --all --pretty=format:'%Cred%h%Creset - %s %Cgreen(%cr) %C(bold blue)%an%Creset %C(yellow)%d%Creset'";
        serve = "!git daemon --reuseaddr --verbose  --base-path=. --export-all ./.git";
        m = "!git checkout $(git defaultBranch)";
        unstage = "reset HEAD --";
      };

      help.autocorrect = 1;
      push.default = "simple";
      pull.rebase = false;

      "branch \"main\"".mergeoptions = "--no-edit";
      init.defaultBranch = "main";

      gpg.program = "gpg";
    };
  };

  home.stateVersion = "25.05";
}
