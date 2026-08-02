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
    configType = "lua";
    systemd.enable = false;

    settings = {
      mod._var = "SUPER";

      monitor = [
        {
          output = "eDP-1";
          mode = "1920x1200@60.00";
          position = "0x0";
          scale = 1;
        }
        {
          output = "DP-2";
          mode = "1920x1080@60.00";
          position = "1920x0";
          scale = 1;
        }
        {
          output = "DP-1";
          mode = "1920x1080@60.00";
          position = "3840x0";
          scale = 1;
        }
      ];

      config = {
        # Keyboard pro Host
        input = {
          kb_layout = "us";
          kb_variant = "altgr-intl";
          kb_options = "grp:alt_shift_toggle";
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
          col = {
            active_border = "rgba(bb9af7ff)";
            inactive_border = "rgba(d1bfffcc)";
            nogroup_border = "rgba(d1bfffcc)";
            nogroup_border_active = "rgba(bb9af7ff)";
          };
        };
      };

      # Window rules
      window_rule = [
        {
          name = "opacity-all";
          match.class = ".*";
          opacity = "0.95 0.9 1.0";
        }
        {
          name = "kitty-fullscreen-opaque";
          match.class = "^(kitty|Kitty)$";
          match.fullscreen = true;
          opacity = "1.0 1.0 1.0";
        }
        {
          name = "kitty-not-fullscreen";
          match.class = "^(kitty|Kitty)$";
          match.fullscreen = false;
          opacity = "0.9 0.85 1.0";
        }
        # Ignore maximize requests from all apps
        {
          name = "suppress-maximize-events";
          match.class = ".*";
          suppress_event = "maximize";
        }

        # Fix some dragging issues with XWayland
        {
          name = "fix-xwayland-drags";
          match = {
            class = "^$";
            title = "^$";
            xwayland = true;
            float = true;
            fullscreen = false;
            pin = false;
          };
          no_focus = true;
        }
      ];
    };

    extraConfig = ''
      local function bind_exec(key, command, opts)
        if opts == nil then
          hl.bind(key, hl.dsp.exec_cmd(command))
        else
          hl.bind(key, hl.dsp.exec_cmd(command), opts)
        end
      end

      -- Startup-Apps (Hyprland-Panel, Waybar, Notifier, etc.)
      -- TODO: use a more robust script that checks if the vms are up and responding before starting the tray apps.
      hl.on("hyprland.start", function()
        hl.exec_cmd("waybar")
        hl.exec_cmd("systemctl --user restart wpaperd.service")
        hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
        hl.exec_cmd("vm-run sn nm-applet --indicator")
        hl.exec_cmd("vm-run c vesktop -m")
        hl.exec_cmd("vm-run c element-desktop --hidden")
        hl.exec_cmd("vm-run c Telegram -startintray")
        hl.exec_cmd("[workspace 3 silent] kitty")
        hl.exec_cmd("[workspace 2 silent] kitty --session=none remote-zellij i")
        hl.exec_cmd("[workspace special:magic silent] vm-run net zen")
      end)

      bind_exec(mod .. " + A", [[pkill rofi || rofi -modi drun,filebrowser,window,run -show drun -theme ~/.config/rofi/config.rasi]])
      bind_exec(mod .. " + B", "vm-run net zen")

      hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mod .. " + Z", hl.dsp.window.pseudo()) -- dwindle
      hl.bind(mod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle

      -- Lock screen
      bind_exec(mod .. " + L", "hyprlock")

      -- Focus movement
      hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
      hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
      hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))

      -- Move windows
      hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
      hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
      hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

      -- Resize windows
      hl.bind(mod .. " + CTRL + left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
      hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
      hl.bind(mod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
      hl.bind(mod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }))

      -- Switch layout
      hl.bind(mod .. " + M", hl.dsp.layout("swapwithmaster"))
      hl.bind(mod .. " + Y", hl.dsp.layout("focusmaster"))
      hl.bind(mod .. " + D", hl.dsp.layout("addmaster"))

      for i = 1, 10 do
        local key = i % 10
        hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
      end

      -- Special workspace
      hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
      hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

      hl.bind(mod .. " + Q", hl.dsp.window.close())

      -- Kitty-Special
      bind_exec(mod .. " + SHIFT + K", "kitty --session=none")
      bind_exec(mod .. " + T", "kitty")

      -- emoji picker
      bind_exec(mod .. " + comma", [[rofimoji --max-recent 10 --action copy --selector-args='-theme ~/.config/rofi/config.rasi']])

      -- Fullscreen toggle
      hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

      -- Screenshots
      bind_exec(mod .. " + P", [[grim -g "$(slurp)" - | satty --filename -]])
      bind_exec(mod .. " + SHIFT + P", "grim - | satty --filename -")

      -- Screen recording (toggle start/stop)
      bind_exec(mod .. " + R", "screenrec-region")
      bind_exec(mod .. " + SHIFT + R", "screenrec-full")

      -- yazi
      bind_exec(mod .. " + E", "explorer")

      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d intel_backlight -e4 -n2 set 5%+"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d intel_backlight -e4 -n2 set 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

      hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
      hl.bind(mod .. " + ALT + mouse:272", hl.dsp.window.resize(), { mouse = true })
    '';
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
