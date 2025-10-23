{ ... }:
{
  hydenix.hm = {
    enable = true;
    editors = {
      enable = true; # enable editors module
      neovim = false;
      vscode.enable = false;
      vim.enable = false;
      default = "nvim"; # default text editor
    };
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

      keybindings = {
        enable = true; # enable keybindings configurations
        extraConfig = ''
          bind = SUPER, F, exec, firefox
        ''; # additional keybindings configuration
        overrideConfig = null; # complete keybindings configuration override (null or lib.types.lines)
      };
    };

    firefox.enable = false;
  };
}
