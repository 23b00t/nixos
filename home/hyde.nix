{ ... }:
{
  hydenix.hm = {
    enable = true;
    editors.enable = false;
    git.enable = false;
    shell.enable = false;
    terminals.enable = false;
    hyprland = {
      monitors = {
        enable = true;
        overrideConfig = ''
          monitor=HDMI-A-1,1920x1080@60,0x0,1
          monitor=eDP-1,1920x1080@60,1920x0,1
        '';
      };

      extraConfig = ''
        input {
          kb_layout = us,de
          kb_variant = altgr-intl, 
          kb_options = grp:alt_shift_toggle
        }
        # exec-once = .local/lib/hyde/wallpaper.sh -s ~/nixos-config/wallpapers/edger_lucy_neon.jpg
        # exec-once = swww img -o HDMI-A-1 ~/nixos-config/wallpapers/edger_lucy_neon.jpg
        # exec-once = swww img -o eDP-1 ~/nixos-config/wallpapers/1.png
        exec-once = ~/nixos-config/home/set-wallpapers.sh
      '';

      keybindings = {
        enable = true; # enable keybindings configurations
        extraConfig = ''
          bind = SUPER, F, exec, firefox
          bind = SUPER SHIFT, K, exec, keybinds_hint.sh
        ''; # additional keybindings configuration
        overrideConfig = null; # complete keybindings configuration override (null or lib.types.lines)
      };
    };

    waybar = {
      enable = true; # enable waybar module
      userStyle = ''
        * {
          font-size: 14px;
        }
      '';
      # custom waybar user-style.css
    };
    theme.active = "Tokyo Night";

    firefox.enable = false;
  };

  # home.file.".config/waybar/user-style.css".text = ''
  #   * {
  #     font-size: 14px;
  #   }
  # '';
}
