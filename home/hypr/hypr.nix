{
  pkgs,
  config,
  hostname,
  ...
}:
{
  home.packages = with pkgs; [
    wl-screenrec

    # Screen recording helper scripts
    (writeShellScriptBin "screenrec-region" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      # Toggle: wenn schon läuft, Recording stoppen
      if pgrep -x wl-screenrec >/dev/null; then
        ${pkgs.libnotify}/bin/notify-send "Screen recording" "Region recording stopped"
        pkill -INT wl-screenrec
        exit 0
      fi

      OUTDIR="''${XDG_VIDEOS_DIR:-''$HOME/Videos}/ScreenRecordings"
      mkdir -p "$OUTDIR"
      FILE="$OUTDIR/region-$(date +'%Y-%m-%d_%H-%M-%S').mp4"

      ${pkgs.libnotify}/bin/notify-send "Screen recording" "Region recording started → $FILE"
      wl-screenrec -g "$(slurp)" -f "$FILE" --low-power=off
    '')

    (writeShellScriptBin "screenrec-full" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      # Toggle: wenn schon läuft, Recording stoppen
      if pgrep -x wl-screenrec >/dev/null; then
        ${pkgs.libnotify}/bin/notify-send "Screen recording" "Fullscreen recording stopped"
        pkill -INT wl-screenrec
        exit 0
      fi

      OUTDIR="''${XDG_VIDEOS_DIR:-''$HOME/Videos}/ScreenRecordings"
      mkdir -p "$OUTDIR"
      FILE="$OUTDIR/full-$(date +'%Y-%m-%d_%H-%M-%S').mp4"

      # aktuellen Monitor aus Hyprland ermitteln
      MONITOR="$(hyprctl monitors | awk '/Monitor/{mon=$2} /focused:/{if($2=="yes") print mon}')"

      ${pkgs.libnotify}/bin/notify-send "Screen recording" "Fullscreen recording started on $MONITOR → $FILE"
      wl-screenrec -o "$MONITOR" -f "$FILE" --low-power=off
    '')

    swaynotificationcenter
    rofimoji
    # Screenshots
    grim
    slurp
    satty
    # Lock screen
    hyprlock

    adw-gtk3
    adwaita-qt
    libsForQt5.qtstyleplugin-kvantum

    glib
    dconf
    gsettings-desktop-schemas
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;

    settings = {
      # Monitore pro Host
      monitor =
        if hostname == "xmg" then
          [
            "eDP-1,1920x1200@60.00,0x0,1"
            "DP-1,1920x1080@60.00,1920x0,1"
            "DP-2,1680x1050@59.88,3840x0,1"
          ]
        else if hostname == "hp" then
          [
            "HDMI-A-1,1920x1080@60,0x0,1"
            "eDP-1,1920x1080@60,1920x0,1"
          ]
        else
          [
            "eDP-1,preferred,auto,1"
          ];

      # Keyboard pro Host
      input =
        if hostname == "xmg" then
          {
            kb_layout = "us";
            kb_variant = "altgr-intl";
            kb_options = "grp:alt_shift_toggle";
          }
        else if hostname == "hp" then
          {
            kb_layout = "us,de";
            kb_variant = "altgr-intl";
            kb_options = "grp:alt_shift_toggle";
          }
        else
          {
            kb_layout = "us";
          };

      decoration = {
        rounding = 10;

        # light transparency for all windows
        active_opacity = 0.95;
        inactive_opacity = 0.90;
        fullscreen_opacity = 1.0;

        # blur behind windows
        blur = {
          enabled = true;
          size = 6; # blur strength
          passes = 2; # more = softer, but slower
          new_optimizations = true;
        };
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        # layout = "dwindle";
        layout = "master";

        # Window border colors
        "col.active_border" = "rgba(bb9af7ff)";
        "col.inactive_border" = "rgba(d1bfffcc)";
        "col.nogroup_border" = "rgba(d1bfffcc)";
        "col.nogroup_border_active" = "rgba(bb9af7ff)";
      };

      "$mod" = "SUPER";

      bind = [
        "$mod, A, exec, pkill rofi || rofi -modi drun,filebrowser,window,run -show drun -theme ~/.config/rofi/config.rasi"
        "$mod, B, exec, vm-run net zen"

        "$mod, V, togglefloating,"
        "$mod, P, pseudo," # dwindle
        "$mod, J, togglesplit," # dwindle

        # Lock screen
        "$mod, L, exec, hyprlock"

        # Focus movement
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        # Move windows
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        # Resize windows
        "$mod CTRL, left, resizeactive, -20 0"
        "$mod CTRL, right, resizeactive, 20 0"
        "$mod CTRL, up, resizeactive, 0 -20"
        "$mod CTRL, down, resizeactive, 0 20"
        # Switch layout
        "$mod, M, layoutmsg, swapwithmaster"
        "$mod, Y, layoutmsg, focusmaster"
        "$mod, D, layoutmsg, addmaster"

        # Workspace switching
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Special workspace
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"
        "$mod, Q, killactive,"
        # Kitty-Special
        "$mod SHIFT, K, exec, kitty --session=none"
        "$mod, T, exec, kitty"
        # emoji picker
        "$mod, comma, exec, rofimoji --max-recent 10 --action copy --selector-args='-theme ~/.config/rofi/config.rasi'"

        # Fullscreen toggle
        "$mod, F, fullscreen, 0"

        # Screenshots
        "$mod, P, exec, grim -g \"$(slurp)\" - | satty --filename -"
        "$mod SHIFT, P, exec, grim - | satty --filename -"
        # Screen recording (toggle start/stop)
        "$mod, R, exec, screenrec-region"
        "$mod SHIFT, R, exec, screenrec-full"
        # yazi
        "$mod, E, exec, kitty -e yazi"
      ];

      bindl = [
        ",XF86MonBrightnessUp, exec, brightnessctl -d intel_backlight -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -d intel_backlight -e4 -n2 set 5%-"
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
      ];

      # Startup-Apps (Hyprland-Panel, Waybar, Notifier, etc.)
      exec-once = [
        "waybar"
        "systemctl --user restart wpaperd.service"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "sleep 10 && vm-run sn nm-applet --indicator"
        "sleep 5 && vm-run c vesktop -m"
        "sleep 5 && vm-run c element-desktop --hidden"
        "sleep 5 && vm-run c Telegram -startintray"
        "[workspace 2 silent] sleep 5 && kitty"
        "[workspace 3 silent] sleep 8 && kitty --session=none remote-zellij i"
        "[workspace special:magic silent] sleep 5 && vm-run net zen"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
        "$mod ALT, mouse:272, resizewindow"
      ];

      # Window rules
      windowrule = [
        {
          name = "opacity-all";
          "match:class" = ".*";
          opacity = "0.95 0.9 1.0";
        }
        {
          name = "kitty-fullscreen-opaque";
          "match:class" = "^(kitty|Kitty)$";
          "match:fullscreen" = true;
          opacity = "1.0 1.0 1.0";
        }
        {
          name = "kitty-not-fullscreen";
          "match:class" = "^(kitty|Kitty)$";
          "match:fullscreen" = false;
          opacity = "0.9 0.85 1.0";
        }
        # Ignore maximize requests from all apps
        {
          name = "suppress-maximize-events";
          "match:class" = ".*";
          suppress_event = "maximize";
        }

        # Fix some dragging issues with XWayland
        {
          name = "fix-xwayland-drags";
          "match:class" = "^$";
          "match:title" = "^$";
          "match:xwayland" = true;
          "match:float" = true;
          "match:fullscreen" = false;
          "match:pin" = false;
          no_focus = true;
        }
      ];
    };
  };

  services.wpaperd.enable = true;
  services.wpaperd.settings = {
    "DP-1" = {
      path = "${config.home.homeDirectory}/nixos-config/wallpapers/edger_lucy_neon.jpg";
    };

    "DP-2" = {
      path = "${config.home.homeDirectory}/nixos-config/wallpapers/ntc.jpg";
    };

    "eDP-1" = {
      path = "${config.home.homeDirectory}/nixos-config/wallpapers/cat_lofi_cafe.jpg";
    };
  };

  services.swaync = {
    enable = true;
    package = pkgs.swaynotificationcenter;
  };

  # services.dunst = {
  #   enable = true;
  # };
}
