{ pkgs, yazi, ... }:
let
  # nix shell "nixpkgs#nix-prefetch-git"
  # nix-prefetch-git --url https://github.com/yazi-rs/plugins --rev d1c8baa
  yazi-plugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "d1c8baab86100afb708694d22b13901b9f9baf00";
    hash = "sha256-52Zn6OSSsuNNAeqqZidjOvfCSB7qPqUeizYq/gO+UbE=";
  };
in
{
  programs.yazi = {
    enable = true;
    package = yazi.packages.${pkgs.system}.default;
    enableZshIntegration = true;
    shellWrapperName = "y";

    settings = {
      mgr = {
        show_hidden = true;
        linemode = "size";
      };
      # preview = {
      #   max_width = 1000;
      #   max_height = 1000;
      # };
      plugin = {
        prepend_fetchers = [
          {
            id = "git";
            name = "*";
            run = "git";
          }
          {
            id = "git";
            name = "*/";
            run = "git";
          }
        ];
      };
    };

    plugins = {
      full-border = "${yazi-plugins}/full-border.yazi";
      git = "${yazi-plugins}/git.yazi";
      mount = "${yazi-plugins}/mount.yazi";
      chmod = "${yazi-plugins}/chmod.yazi";
      "jump-to-char" = "${yazi-plugins}/jump-to-char.yazi";
    };

    initLua = ''
      			require("full-border"):setup()
            require("git"):setup()
      		'';

    keymap = {
      mgr.prepend_keymap = [
        {
          on = "M";
          run = "plugin mount";
          desc = "Maximize or restore the preview pane";
        }
        {
          on = [
            "c"
            "m"
          ];
          run = "plugin chmod";
          desc = "Chmod on selected files";
        }
        {
          on = "F";
          run = "plugin jump-to-char";
          desc = "Jump to char";
        }
      ];
    };
  };

  # home.file.".config/yazi/flavors/tokyo-night.yazi".source = pkgs.fetchFromGitHub {
  #   owner = "BennyOe";
  #   repo = "tokyo-night.yazi";
  #   rev = "5f5636427f9bb16cc3f7c5e5693c60914c73f036";
  #   hash = "sha256-4aNPlO5aXP8c7vks6bTlLCuyUQZ4Hx3GWtGlRmbhdto=";
  # };
  #
  # home.file.".config/yazi/theme.toml".text = ''
  #   [flavor]
  #   dark = "tokyo-night"
  # '';
}
