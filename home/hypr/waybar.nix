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
        /* Tokyo Night inspired Waybar style */

        * {
          font-family: "FiraCode Nerd Font", "Symbols Nerd Font";
          font-size: 14px;
          font-weight: bold;
          border-radius: 8px;
          min-height: 0;
        }

        window#waybar {
          background-color: rgba(26, 27, 38, 0.85);
          color: #c0caf5;
          border-radius: 12px;
          border: 1px solid #3b4261;
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
          background-color: transparent;
          color: #565f89;
          border-radius: 6px;
          transition: background-color 0.2s ease, color 0.2s ease;
        }

        #workspaces button.active,
        #workspaces button.focused {
          background: linear-gradient(135deg, #7aa2f7, #bb9af7);
          color: #1a1b26;
        }

        #workspaces button.urgent {
          background-color: #f7768e;
          color: #1a1b26;
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
          margin: 0 0.5px;
          background-color: rgba(42, 32, 64, 0.50);
          color: #c0caf5;
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
            "format": "{:%A, %d.%m.%Y - %H:%M}",
            "format-alt": "{:%H:%M}",
            "tooltip-format": "{:%Y-%m-%d %H:%M:%S}"
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

            "format-source": " {volume}%",
            "format-source-muted": " mute",
          },

          "battery": {
            "states": {
              "good": 80,
              "warning": 30,
              "critical": 15
            },
            "format": "{icon} {capacity}%",
            "format-charging": " {capacity}%",
            "format-plugged": " {capacity}%",
            "format-alt": "{time} remaining",
            "interval": 30,
            "tooltip": true,
            "format-icons": ["", "", "", "", ""]
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
            "on-click": "blueman-manager"
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
            "format": "{}",
            "tooltip": true,
            "exec": "sensors | grep -m 1 'Package id 0:' | awk '{print $4}'",
            "interval": 5
          },
        }
      '';
      force = true;
    };
  };
}
