{ pkgs, ... }:
let
  yazi-plugins = pkgs.fetchgit {
    url = "https://github.com/yazi-rs/plugins";
  };
in
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";

    settings = {
      mgr = {
        show_hidden = true;
      };
      preview = {
        max_width = 1000;
        max_height = 1000;
      };
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
      flavor = "tokyonight";
    };

    plugins = {
      full-border = "${yazi-plugins}/full-border.yazi";
      git = "${yazi-plugins}/git.yazi";
      mount = "${yazi-plugins}/mount.yazi";
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
      ];
    };
  };
}
