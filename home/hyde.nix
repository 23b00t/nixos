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
          kb_variant = intl
          kb_options = grp:alt_shift_toggle
        }

        # Set wallpaper per workspace using exec-on-workspace
        exec-on-workspace = 1, swww img ~/nixos-config/wallpapers/1.png
        exec-on-workspace = 3, swww img ~/nixos-config/wallpapers/3.png
        exec-on-workspace = 4, swww img ~/nixos-config/wallpapers/5.png
      '';

      keybindings = {
        enable = true; # enable keybindings configurations
        extraConfig = ''
          bind = SUPER, F, exec, firefox
        ''; # additional keybindings configuration
        overrideConfig = null; # complete keybindings configuration override (null or lib.types.lines)
      };
    };

    theme.active = "Tokyo Night";

    firefox.enable = false;
  };
}
