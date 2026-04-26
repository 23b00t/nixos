{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    waybar # system bar
  ];

  home.file = {
    ".config/waybar/style.css" = {
      text = ''
        /* Custom theme colors */
        @define-color bar-bg rgba(0, 0, 0, 0.1);
        @define-color main-bg rgba(36, 40, 59, 0.8);
        @define-color main-fg #7aa2f7;
        @define-color wb-act-bg #bb9af7;
        @define-color wb-act-fg #b4f9f8;
        @define-color wb-hvr-bg #7aa2f7;
        @define-color wb-hvr-fg #cfc9c2;

        * {
          font-family: "FiraCode Nerd Font", "FiraCode Nerd Font", "Symbols Nerd Font";
          font-size: 14px;
          font-weight: 500;
          border-radius: 8px;
          min-height: 0;
        }

        window#waybar {
          background-color: @bar-bg;
          color: @main-fg;
          border-radius: 12px;
        }

        window#waybar.hidden {
          opacity: 0.0;
        }

        #workspaces {
          margin: 0 4px;
        }

        #workspaces button {
          padding: 0 8px;
          margin: 0 2px;
          background-color: rgba(122, 162, 247, 0.10); /* leichtes Blau als Hintergrund */
          color: @main-fg;
          border-radius: 6px;
          transition: background-color 0.2s ease, color 0.2s ease;
        }

        #workspaces button.active,
        #workspaces button.focused {
          background: linear-gradient(135deg, @wb-hvr-bg, @wb-act-bg);
          color: @wb-act-fg;
        }

        #workspaces button.urgent {
          background-color: #f7768e;
          color: @main-bg;
        }

        #clock,
        #battery,
        #pulseaudio,
        #pulseaudio.microphone,
        #memory,
        #cpu,
        #backlight,
        #tray,
        #custom-bluetooth,
        #custom-sensorsinfo,
        #custom-swaync,
        #custom-cputemp {
          padding: 0 10px;
          margin: 0 1px;
          background-color: @main-bg;
          color: @main-fg;
          border-radius: 8px;
        }

        #tray menu {
          background-color: #2a2040;
          color: #c0caf5;
          border-radius: 8px;
          border: 1px solid #2a2261;
        }

        #battery.charging,
        #battery.plugged {
          color: #9ece6a;
        }

        #battery.warning {
          color: #e0af68;
        }

        #battery.critical {
          color: #f7768e;
        }

        #pulseaudio.muted {
          color: #565f89;
        }

        tooltip {
          background: #1a1b26;
          color: #c0caf5;
          border-radius: 8px;
          border: 1px solid #3b4261;
        }

        tooltip label {
          padding: 4px 8px;
        }
      '';
      force = true;
    };

    # CPU-Temp-Script
    ".config/waybar/scripts/cputemp.sh" = {
      text = ''
        #!/usr/bin/env bash
        temp=$(sensors | grep -m 1 'Package id 0:' | awk '{print $4}' | sed 's/+//;s/[^0-9.]//g')
        if [[ -z "$temp" ]]; then
          echo "?"
          exit 0
        fi
        temp_int=''${temp%.*}
        if [[ $temp_int -ge 85 ]]; then
          color="#f7768e"
        elif [[ $temp_int -ge 76 ]]; then
          color="#e0af68"
        else
          color="#7aa2f7"
        fi
        echo "<span color=\"$color\">$temp°C</span>"
      '';
      executable = true;
      force = true;
    };

    # Battery notification script
    ".config/waybar/scripts/battery-notify.sh" = {
      text = ''
        #!/usr/bin/env bash

        bat_dir=""
        for candidate in /sys/class/power_supply/BAT*; do
          if [[ -r "$candidate/capacity" && -r "$candidate/status" ]]; then
            bat_dir="$candidate"
            break
          fi
        done

        [[ -n "$bat_dir" ]] || exit 0

        capacity=$(<"$bat_dir/capacity")
        status=$(<"$bat_dir/status")

        # Exit if not discharging
        if [[ "$status" != "Discharging" ]]; then
          exit 0
        fi

        if [[ "$capacity" -le 20 ]]; then
          notify-send -u critical "Battery critical" "Battery level is $capacity%. Please plug in."
        elif [[ "$capacity" -le 40 ]]; then
          notify-send -u normal "Battery low" "Battery level is $capacity%."
        fi
      '';
      executable = true;
      force = true;
    };

    ".config/waybar/config.jsonc" = {
      text = ''
        {
          // Global bar options
          "layer": "top",
          "position": "top",
          "height": 30,
          "margin-left": 8,
          "margin-right": 8,
          "margin-top": 4,
          "spacing": 6,
          "reload_style_on_change": true,

          // Layout without external JSONC modules/includes
          "modules-left": [
            "hyprland/workspaces",
            "wlr/taskbar"
          ],
          "modules-center": [
            "memory",
            "cpu",
            "custom/cputemp",
            "clock"
          ],
          "modules-right": [
            "backlight",
            "tray",
            "custom/bluetooth",
            "pulseaudio",
            "pulseaudio#microphone",
            "battery",
            "custom/swaync",
          ],

          "hyprland/workspaces": {
            "format": "{name}",
            "sort-by-number": true,
            "all-outputs": true,
            "disable-scroll": false
          },

          "wlr/taskbar": {
            "format": "{icon}",
            "icon-size": 16,
            "markup": false,
            "on-click": "activate",
            "on-click-middle": "close",
            "ignore-list": []
          },

          "clock": {
            "format": "{:%H:%M   %a, %d.%m.%y}",
            "format-alt": "{:%H:%M}",
            "tooltip-format": "<tt><small>{calendar}</small></tt>",
            "calendar": {
              "mode"          : "year",
              "mode-mon-col"  : 3,
              "weeks-pos"     : "right",
              "on-scroll"     : 1,
              "on-click-right": "mode",
              "format": {
                "months":     "<span color='#ffead3'><b>{}</b></span>",
                "days":       "<span color='#ecc6d9'><b>{}</b></span>",
                "weeks":      "<span color='#99ffdd'><b>W{}</b></span>",
                "weekdays":   "<span color='#ffcc66'><b>{}</b></span>",
                "today":      "<span color='#ff6699'><b><u>{}</u></b></span>"
              }
            },
            "actions": {
              "on-click-right": "mode",
              "on-click-forward": "tz_up",
              "on-click-backward": "tz_down",
              "on-scroll-up": "shift_up",
              "on-scroll-down": "shift_down"
            }
          },

          "memory": {
            "format": " {used:0.1f}G",
            "tooltip": true
          },

          "cpu": {
            "format": " {usage:2}%",
            "tooltip": true
          },

          "backlight": {
            "format": " {percent}%",
            "on-scroll-up": "brightnessctl set +5%",
            "on-scroll-down": "brightnessctl set 5%-"
          },

          "pulseaudio": {
            "format": "{icon} {volume}%",
            "format-muted": " mute",
            "on-click": "pavucontrol",
            "scroll-step": 5,
            "format-icons": {
              "default": ["", "", ""]
            }
          },

          "pulseaudio#microphone": {
            "format": "{format_source}",

            "format-source": "{volume}%",
            "format-source-muted": " mute",
          },

          "battery": {
            "states": {
              "good": 80,
              "warning": 40,
              "critical": 20
            },
            "format": "{icon} {capacity}%",
            "format-charging": " {capacity}%",
            "format-plugged": " {capacity}%",
            "format-alt": "{time} remaining",
            "interval": 30,
            "tooltip": true,
            "format-icons": ["", "", "", "", ""],
            "events": {
              "on-discharging-warning": "~/.config/waybar/scripts/battery-notify.sh",
              "on-discharging-critical": "~/.config/waybar/scripts/battery-notify.sh"
            }
          },

          "tray": {
            "icon-size": 16,
            "spacing": 8
          },

          "custom/bluetooth": {
            "format": "",
            "tooltip": false,
            "exec": "echo ",
            "interval": 3600,
            "on-click": "vm-run su dbus-run-session -- blueman-manager"
          },

          "custom/sensorsinfo": {
            "format": "",
            "tooltip": true,
            "exec": "sensors",
            "interval": 30
          },

          "custom/swaync": {
            "format": "",
            "tooltip": "Notifications",
            "on-click": "swaync-client -t"
          },

          "custom/cputemp": {
            "format": " {}",
            "tooltip": true,
            "exec": "~/.config/waybar/scripts/cputemp.sh",
            "interval": 5,
          },
        }
      '';
      force = true;
    };
  };
}
