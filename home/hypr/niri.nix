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

      MONITOR="$(${pkgs.niri}/bin/niri msg --json focused-output | ${pkgs.python3}/bin/python3 -c 'import json, sys; data = json.load(sys.stdin); print(data.get("name", "") if isinstance(data, dict) else "")')"

      if [[ -z "$MONITOR" ]]; then
        ${pkgs.libnotify}/bin/notify-send -u critical "Screen recording" "Focused output could not be determined"
        exit 1
      fi

      ${pkgs.libnotify}/bin/notify-send "Screen recording" "Fullscreen recording started on $MONITOR → $FILE"
      wl-screenrec -o "$MONITOR" -f "$FILE" --low-power=off
    '')

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

  wayland.windowManager.niri = {
    enable = true;

    settings = {
      "prefer-no-csd" = { };
      "screenshot-path" = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      input = {
        "mod-key" = "Super";

        keyboard = {
          xkb = {
            layout = "us";
            variant = "altgr-intl";
            options = "grp:alt_shift_toggle";
          };

          numlock = { };
        };

        touchpad = {
          tap = { };
          "natural-scroll" = { };
        };
      };

      layout = {
        gaps = 10;
        "center-focused-column" = "on-overflow";
        "always-center-single-column" = { };

        "preset-column-widths"._children = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
        ];

        "default-column-width".proportion = 0.5;

        "focus-ring" = {
          width = 2;
          "active-color" = "#bb9af7";
          "inactive-color" = "#d1bfffcc";
          "urgent-color" = "#f7768e";
        };

        border.off = { };

        shadow = {
          on = { };
          softness = 30;
          spread = 5;
          offset._props = {
            x = 0;
            y = 5;
          };
          color = "#00000070";
        };
      };

      binds = {
        "Mod+Shift+Slash"."show-hotkey-overlay" = { };

        "Mod+T" = {
          _props."hotkey-overlay-title" = "Open a Terminal: kitty";
          spawn = [ "kitty" ];
        };

        "Mod+A" = {
          _props."hotkey-overlay-title" = "Run an Application: rofi";
          "spawn-sh" = "pkill rofi || rofi -modi drun,filebrowser,window,run -show drun -theme ~/.config/rofi/config.rasi";
        };

        "Mod+D" = {
          _props."hotkey-overlay-title" = "Run an Application: rofi";
          "spawn-sh" = "pkill rofi || rofi -modi drun,filebrowser,window,run -show drun -theme ~/.config/rofi/config.rasi";
        };

        "Mod+B" = {
          _props."hotkey-overlay-title" = "Open Browser VM";
          "spawn-sh" = "vm-run net zen";
        };

        "Mod+L" = {
          _props."hotkey-overlay-title" = "Lock the Screen: hyprlock";
          spawn = [ "hyprlock" ];
        };

        "Mod+Shift+K" = {
          _props."hotkey-overlay-title" = "Open Secondary Kitty";
          spawn = [
            "kitty"
            "--session=none"
          ];
        };

        "Mod+Comma" = {
          _props."hotkey-overlay-title" = "Emoji Picker";
          "spawn-sh" = "rofimoji --max-recent 10 --action copy --selector-args='-theme ~/.config/rofi/config.rasi'";
        };

        "Mod+E" = {
          _props."hotkey-overlay-title" = "Open Explorer";
          spawn = [ "explorer" ];
        };

        "Mod+P" = {
          _props."hotkey-overlay-title" = "Region Screenshot";
          "spawn-sh" = "grim -g \"$(slurp)\" - | satty --filename -";
        };

        "Mod+Shift+P" = {
          _props."hotkey-overlay-title" = "Fullscreen Screenshot";
          "spawn-sh" = "grim - | satty --filename -";
        };

        "Mod+R" = {
          _props."hotkey-overlay-title" = "Region Recording";
          spawn = [ "screenrec-region" ];
        };

        "Mod+Shift+R" = {
          _props."hotkey-overlay-title" = "Fullscreen Recording";
          spawn = [ "screenrec-full" ];
        };

        "XF86AudioRaiseVolume" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
        };

        "XF86AudioLowerVolume" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        };

        "XF86AudioMute" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };

        "XF86AudioMicMute" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        };

        "XF86MonBrightnessUp" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "brightnessctl -d intel_backlight -e4 -n2 set 5%+";
        };

        "XF86MonBrightnessDown" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "brightnessctl -d intel_backlight -e4 -n2 set 5%-";
        };

        "XF86AudioPlay" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "playerctl play-pause";
        };

        "XF86AudioPause" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "playerctl play-pause";
        };

        "XF86AudioPrev" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "playerctl previous";
        };

        "XF86AudioNext" = {
          _props."allow-when-locked" = true;
          "spawn-sh" = "playerctl next";
        };

        "Mod+O" = {
          _props.repeat = false;
          "toggle-overview" = { };
        };

        "Mod+Q" = {
          _props.repeat = false;
          "close-window" = { };
        };

        "Mod+Left"."focus-column-left" = { };
        "Mod+Down"."focus-window-down" = { };
        "Mod+Up"."focus-window-up" = { };
        "Mod+Right"."focus-column-right" = { };
        "Mod+H"."focus-column-left" = { };
        "Mod+J"."focus-window-down" = { };
        "Mod+K"."focus-window-up" = { };

        "Mod+Ctrl+Left"."move-column-left" = { };
        "Mod+Ctrl+Down"."move-window-down" = { };
        "Mod+Ctrl+Up"."move-window-up" = { };
        "Mod+Ctrl+Right"."move-column-right" = { };
        "Mod+Ctrl+H"."move-column-left" = { };
        "Mod+Ctrl+J"."move-window-down" = { };
        "Mod+Ctrl+K"."move-window-up" = { };

        "Mod+Home"."focus-column-first" = { };
        "Mod+End"."focus-column-last" = { };
        "Mod+Ctrl+Home"."move-column-to-first" = { };
        "Mod+Ctrl+End"."move-column-to-last" = { };

        "Mod+Shift+Left"."focus-monitor-left" = { };
        "Mod+Shift+Down"."focus-monitor-down" = { };
        "Mod+Shift+Up"."focus-monitor-up" = { };
        "Mod+Shift+Right"."focus-monitor-right" = { };
        "Mod+Shift+H"."focus-monitor-left" = { };
        "Mod+Shift+J"."focus-monitor-down" = { };

        "Mod+Shift+Ctrl+Left"."move-column-to-monitor-left" = { };
        "Mod+Shift+Ctrl+Down"."move-column-to-monitor-down" = { };
        "Mod+Shift+Ctrl+Up"."move-column-to-monitor-up" = { };
        "Mod+Shift+Ctrl+Right"."move-column-to-monitor-right" = { };
        "Mod+Shift+Ctrl+H"."move-column-to-monitor-left" = { };
        "Mod+Shift+Ctrl+J"."move-column-to-monitor-down" = { };
        "Mod+Shift+Ctrl+K"."move-column-to-monitor-up" = { };

        "Mod+Page_Down"."focus-workspace-down" = { };
        "Mod+Page_Up"."focus-workspace-up" = { };
        "Mod+U"."focus-workspace-down" = { };
        "Mod+I"."focus-workspace-up" = { };
        "Mod+Ctrl+Page_Down"."move-column-to-workspace-down" = { };
        "Mod+Ctrl+Page_Up"."move-column-to-workspace-up" = { };
        "Mod+Ctrl+U"."move-column-to-workspace-down" = { };
        "Mod+Ctrl+I"."move-column-to-workspace-up" = { };
        "Mod+Shift+Page_Down"."move-workspace-down" = { };
        "Mod+Shift+Page_Up"."move-workspace-up" = { };
        "Mod+Shift+U"."move-workspace-down" = { };
        "Mod+Shift+I"."move-workspace-up" = { };

        "Mod+WheelScrollDown" = {
          _props."cooldown-ms" = 150;
          "focus-workspace-down" = { };
        };

        "Mod+WheelScrollUp" = {
          _props."cooldown-ms" = 150;
          "focus-workspace-up" = { };
        };

        "Mod+Ctrl+WheelScrollDown" = {
          _props."cooldown-ms" = 150;
          "move-column-to-workspace-down" = { };
        };

        "Mod+Ctrl+WheelScrollUp" = {
          _props."cooldown-ms" = 150;
          "move-column-to-workspace-up" = { };
        };

        "Mod+WheelScrollRight"."focus-column-right" = { };
        "Mod+WheelScrollLeft"."focus-column-left" = { };
        "Mod+Ctrl+WheelScrollRight"."move-column-right" = { };
        "Mod+Ctrl+WheelScrollLeft"."move-column-left" = { };
        "Mod+Shift+WheelScrollDown"."focus-column-right" = { };
        "Mod+Shift+WheelScrollUp"."focus-column-left" = { };
        "Mod+Ctrl+Shift+WheelScrollDown"."move-column-right" = { };
        "Mod+Ctrl+Shift+WheelScrollUp"."move-column-left" = { };

        "Mod+1"."focus-workspace" = 1;
        "Mod+2"."focus-workspace" = 2;
        "Mod+3"."focus-workspace" = 3;
        "Mod+4"."focus-workspace" = 4;
        "Mod+5"."focus-workspace" = 5;
        "Mod+6"."focus-workspace" = 6;
        "Mod+7"."focus-workspace" = 7;
        "Mod+8"."focus-workspace" = 8;
        "Mod+9"."focus-workspace" = 9;
        "Mod+0"."focus-workspace" = 10;

        "Mod+Ctrl+1"."move-column-to-workspace" = 1;
        "Mod+Ctrl+2"."move-column-to-workspace" = 2;
        "Mod+Ctrl+3"."move-column-to-workspace" = 3;
        "Mod+Ctrl+4"."move-column-to-workspace" = 4;
        "Mod+Ctrl+5"."move-column-to-workspace" = 5;
        "Mod+Ctrl+6"."move-column-to-workspace" = 6;
        "Mod+Ctrl+7"."move-column-to-workspace" = 7;
        "Mod+Ctrl+8"."move-column-to-workspace" = 8;
        "Mod+Ctrl+9"."move-column-to-workspace" = 9;
        "Mod+Ctrl+0"."move-column-to-workspace" = 10;

        "Mod+S"."focus-workspace" = "magic";
        "Mod+Shift+S"."move-column-to-workspace" = "magic";

        "Mod+BracketLeft"."consume-or-expel-window-left" = { };
        "Mod+BracketRight"."consume-or-expel-window-right" = { };
        "Mod+Period"."expel-window-from-column" = { };

        "Mod+Shift+Minus"."set-window-height" = "-10%";
        "Mod+Shift+Equal"."set-window-height" = "+10%";

        "Mod+Minus"."set-column-width" = "-10%";
        "Mod+Equal"."set-column-width" = "+10%";
        "Mod+Alt+R"."switch-preset-column-width" = { };
        "Mod+Alt+Shift+R"."switch-preset-column-width-back" = { };
        "Mod+Ctrl+Shift+R"."switch-preset-window-height" = { };
        "Mod+Ctrl+R"."reset-window-height" = { };

        "Mod+V"."toggle-window-floating" = { };
        "Mod+Shift+V"."switch-focus-between-floating-and-tiling" = { };
        "Mod+W"."toggle-column-tabbed-display" = { };

        "Mod+F"."fullscreen-window" = { };
        "Mod+Shift+F"."maximize-column" = { };
        "Mod+M"."maximize-window-to-edges" = { };
        "Mod+Ctrl+F"."expand-column-to-available-width" = { };
        "Mod+C"."center-column" = { };
        "Mod+Ctrl+C"."center-visible-columns" = { };

        Print.screenshot = { };
        "Ctrl+Print"."screenshot-screen" = { };
        "Alt+Print"."screenshot-window" = { };

        "Mod+Escape" = {
          _props."allow-inhibiting" = false;
          "toggle-keyboard-shortcuts-inhibit" = { };
        };

        "Mod+Shift+E".quit = { };
        "Ctrl+Alt+Delete".quit = { };
      };

      _children = [
        { workspace._args = [ "magic" ]; }
        {
          output = {
            _args = [ "eDP-1" ];
            mode = "1920x1200@60.00";
            scale = 1.0;
            position._props = {
              x = 0;
              y = 0;
            };
          };
        }
        {
          output = {
            _args = [ "DP-2" ];
            mode = "1920x1080@60.00";
            scale = 1.0;
            position._props = {
              x = 1920;
              y = 0;
            };
          };
        }
        {
          output = {
            _args = [ "DP-1" ];
            mode = "1920x1080@60.00";
            scale = 1.0;
            position._props = {
              x = 3840;
              y = 0;
            };
          };
        }
        { "spawn-at-startup"._args = [ "waybar" ]; }
        { "spawn-at-startup"._args = [ "systemctl" "--user" "restart" "wpaperd.service" ]; }
        { "spawn-at-startup"._args = [ "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1" ]; }
        { "spawn-at-startup"._args = [ "vm-run" "sn" "nm-applet" "--indicator" ]; }
        { "spawn-at-startup"._args = [ "vm-run" "c" "vesktop" "-m" ]; }
        { "spawn-at-startup"._args = [ "vm-run" "c" "element-desktop" "--hidden" ]; }
        { "spawn-at-startup"._args = [ "vm-run" "c" "Telegram" "-startintray" ]; }
        { "spawn-at-startup"._args = [ "kitty" "--class=kitty-main" ]; }
        {
          "spawn-at-startup"._args = [
            "kitty"
            "--class=kitty-remote-zellij"
            "--session=none"
            "remote-zellij"
            "i"
          ];
        }
        { "spawn-at-startup"._args = [ "vm-run" "net" "zen" ]; }
        {
          "window-rule"._children = [
            {
              match._props = {
                "app-id" = "^kitty-main$";
                "at-startup" = true;
              };
            }
            { "open-on-workspace" = 3; }
          ];
        }
        {
          "window-rule"._children = [
            {
              match._props = {
                "app-id" = "^kitty-remote-zellij$";
                "at-startup" = true;
              };
            }
            { "open-on-workspace" = 2; }
          ];
        }
        {
          "window-rule"._children = [
            {
              match._props = {
                "app-id" = "^(zen|app\\.zen_browser\\.zen)$";
                "at-startup" = true;
              };
            }
            { "open-on-workspace" = "magic"; }
          ];
        }
        {
          "window-rule"._children = [
            { "geometry-corner-radius" = 10; }
            { "clip-to-geometry" = true; }
            { opacity = 0.9; }
            {
              "background-effect" = {
                blur = true;
                saturation = 2.0;
                noise = 0.03;
              };
            }
          ];
        }
        {
          "window-rule"._children = [
            {
              match._props = {
                "is-focused" = true;
              };
            }
            { opacity = 0.95; }
          ];
        }
      ];
    };
  };

  services.wpaperd.enable = true;
  services.wpaperd.settings = {
    "DP-1" = {
      path = "${config.home.homeDirectory}/nixos-config/wallpapers/ntc.jpg";
    };

    "DP-2" = {
      path = "${config.home.homeDirectory}/nixos-config/wallpapers/edger_lucy_neon.jpg";
    };

    "eDP-1" = {
      path = "${config.home.homeDirectory}/nixos-config/wallpapers/cat_lofi_cafe.jpg";
    };
  };

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      cssPriority = "application";
      control-center-margin-top = 0;
      control-center-margin-bottom = 0;
      control-center-margin-right = 0;
      control-center-margin-left = 0;
      notification-2fa-action = true;
      notification-inline-replies = false;
      notification-icon-size = 64;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
    };
    style = ''
      .notification-row {
        outline: none;
      }

      .notification {
        border-radius: 12px;
        margin: 6px 12px;
        box-shadow:
          0 0 0 1px rgba(0, 0, 0, 0.3),
          0 1px 3px 1px rgba(0, 0, 0, 0.7),
          0 2px 6px 2px rgba(0, 0, 0, 0.3);
        padding: 0;
        background: rgba(36, 40, 59, 0.8);
        color: #7aa2f7;
      }
    '';
  };

  # services.dunst = {
  #   enable = true;
  # };
}
