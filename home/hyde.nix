{ lib, ... }:
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
          monitor=eDP-1,1920x1200@60.00,0x0,1
          monitor=DP-1,1920x1080@60.00,1920x0,1
          monitor=DP-2,1680x1050@59.88,3840x0,1
        '';
      };

      extraConfig = ''
        input {
          kb_layout = us
          kb_variant = altgr-intl
          kb_options = grp:alt_shift_toggle
        }
        # exec-once = ~/nixos-config/home/set-wallpapers.sh
      '';

      keybindings = {
        enable = true; # enable keybindings configurations
        extraConfig = ''
          # bind = SUPER, F, exec, gtk-launch "Firefox Web Browser"
          unbind = SUPER, B
          bind = SUPER, B, exec, vm-run net zen
          unbind = ,XF86MonBrightnessUp
          unbind = ,XF86MonBrightnessDown
          bindel = ,XF86MonBrightnessUp, exec, brightnessctl -d intel_backlight -e4 -n2 set 5%+
          bindel = ,XF86MonBrightnessDown, exec, brightnessctl -d intel_backlight -e4 -n2 set 5%-
          bind = SUPER SHIFT, K, exec, kitty --session=none
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

  home.file.".local/share/waybar/layouts/khing.jsonc" = {
    text = "";
    force = true;
  };
  home.activation.patchWaybarLayout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME/.local/share/waybar/layouts/khing.jsonc"
    cp ${./resources/patched-khing.jsonc} "$HOME/.local/share/waybar/layouts/khing.jsonc"
  '';

  # home.file.".config/waybar/user-style.css".text = ''
  #   * {
  #     font-size: 14px;
  #   }
  # '';
}
