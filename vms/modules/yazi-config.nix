{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.yazi ];

  environment.etc."yazi/init.lua".text = ''
    require("full-border"):setup {
      type = ui.Border.ROUNDED,
    }

    require("git"):setup {
      order = 1500,
    }
  '';

  environment.etc."yazi/yazi.toml".text = ''
    [mgr]
    linemode = "size"
    show_hidden = true

    [[plugin.prepend_fetchers]]
    id    = "git"
    url   = "*"
    run   = "git"
    group = "git"

    [[plugin.prepend_fetchers]]
    id    = "git"
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

  environment.etc."yazi/plugins/git.yazi".source = pkgs.yaziPlugins.git;
  environment.etc."yazi/plugins/chmod.yazi".source = pkgs.yaziPlugins.chmod;
  environment.etc."yazi/plugins/mount.yazi".source = pkgs.yaziPlugins.mount;
  environment.etc."yazi/plugins/full-border.yazi".source = pkgs.yaziPlugins.full-border;
  environment.etc."yazi/plugins/jump-to-char.yazi".source = pkgs.yaziPlugins.jump-to-char;
  environment.etc."yazi/plugins/compress.yazi".source = pkgs.yaziPlugins.compress;
  environment.etc."yazi/plugins/smart-paste.yazi".source = pkgs.yaziPlugins.smart-paste;

  systemd.tmpfiles.rules = [
    "d /home/user/.config/yazi 0755 user users -"
    "L+ /home/user/.config/yazi/yazi.toml - - - - /etc/yazi/yazi.toml"
    "L+ /home/user/.config/yazi/init.lua - - - - /etc/yazi/init.lua"
    "L+ /home/user/.config/yazi/plugins - - - - /etc/yazi/plugins"
  ];
}
