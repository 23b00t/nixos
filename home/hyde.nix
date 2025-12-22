{ ... }:
{
  hydenix.hm = {
    enable = true;
    editors.enable = false;
    git.enable = false;
    shell.enable = false;
    terminals.enable = false;
    social.enable = false;
    spotify.enable = false;
    hyprland = {
      monitors = {
        enable = true;
        overrideConfig = ''
          monitor=HDMI-A-1,1920x1080@60,0x0,1
          monitor=eDP-1,1920x1080@60,1920x0,1
        '';
      };

      windowrules = {
        enable = true;
#         overrideConfig = ''
# ''
      };

      extraConfig = ''
        input {
          kb_layout = us,de
          kb_variant = altgr-intl, 
          kb_options = grp:alt_shift_toggle
        }
        exec-once = ~/nixos-config/home/set-wallpapers.sh
      '';

      keybindings = {
        enable = true; # enable keybindings configurations
        extraConfig = ''
          # bind = SUPER, F, exec, gtk-launch "Firefox Web Browser"
          unbind = SUPER, B
          bind = SUPER, B, exec, vm-run 5 net firefox
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
