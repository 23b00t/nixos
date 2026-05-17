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
    # settings are managed externally via TOML file yazi.toml !
    flavors = {
      inherit (pkgs.yaziPlugins) yatline-catppuccin;
    };
  };

  environment.etc."yazi/init.lua".text = ''
    require("full-border"):setup {
      -- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
      type = ui.Border.ROUNDED,
    }
    require("git"):setup {
      -- Order of status signs showing in the linemode
      order = 1500,
    }
  '';
  environment.etc."yazi/yazi.toml".text = ''
    [mgr]
    linemode = "size"
    show_hidden = true

    [[plugin.prepend_fetchers]]
    url   = "*"
    run   = "git"
    group = "git"

    [[plugin.prepend_fetchers]]
    url   = "*/"
    run   = "git"
    group = "git"

    [[mgr.prepend_keymap]]
    desc = "Maximize or restore the preview pane"
    on   = "M"
    run  = "plugin mount"

    [[mgr.prepend_keymap]]
    desc = "Chmod on selected files"
    on   = ["c", "m"]
    run  = "plugin chmod"

    [[mgr.prepend_keymap]]
    desc = "Jump to char"
    on   = "F"
    run  = "plugin jump-to-char"

    [[mgr.prepend_keymap]]
    desc = "Compress selected files"
    on   = "z"
    run  = "plugin compress"

    [[mgr.prepend_keymap]]
    desc = "Smart Paste (context-aware paste)"
    on   = "P"
    run  = "plugin smart-paste"
  '';

  systemd.tmpfiles.rules = [
    "d /home/user/.config/yazi 0755 user users -"
    "L+ /home/user/.config/yazi/yazi.toml - - - - /etc/yazi/yazi.toml"
    "L+ /home/user/.config/yazi/init.lua - - - - /etc/yazi/init.lua"
  ];
}
