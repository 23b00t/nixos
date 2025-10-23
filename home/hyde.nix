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
          monitor=eDP-1,1920x1080@60,1920x0,1.5
        '';
      };

      extraConfig = ''
        input {
          kb_layout = us,de
          kb_variant = intl
          kb_options = grp:alt_shift_toggle
        }
      '';
    };

    firefox.enable = false;
  };
}
