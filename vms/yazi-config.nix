{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    plugins = {
      inherit (pkgs.yaziPlugins)
        git
        chmod
        mount
        full-border
        jump-to-char
        compress
        smart-paste
        yatline-catppuccin
        ;
    };
    settings = {
      yazi = {
        mgr = {
          linemode = "size";
          show_hidden = true;
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
      };
      keymap = {
        mgr = {
          prepend_keymap = [
            {
              desc = "Maximize or restore the preview pane";
              on = "M";
              run = "plugin mount";
            }
            {
              desc = "Chmod on selected files";
              on = [
                "c"
                "m"
              ];
              run = "plugin chmod";
            }
            {
              desc = "Jump to char";
              on = "F";
              run = "plugin jump-to-char";
            }
            {
              desc = "Compress selected files";
              on = "z";
              run = "plugin compress";
            }
            {
              desc = "Smart Paste (context-aware paste)";
              on = "P";
              run = "plugin smart-paste";
            }
          ];
        };
      };
    };
    flavors = {
      inherit (pkgs.yaziPlugins) yatline-catppuccin;
    };
    initLua = builtins.toFile "init.lua" ''
      require("full-border"):setup()
      require("git"):setup()
    '';
  };
}
