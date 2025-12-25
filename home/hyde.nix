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
          monitor=DP-1,1680x1050@59.88,0x0,1
          monitor=HDMI-A-1,1920x1080@60.00,1680x0,1
          monitor=eDP-1,1920x1200@60.00,3600x0,1
        '';
      };

      windowrules = {
        enable = true;
#         overrideConfig = ''
# ''
      };

      extraConfig = ''
        input {
          kb_layout = us
          kb_variant = altgr-intl
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
