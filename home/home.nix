{
  pkgs,
  lib,
  inputs,
  hostname,
  config,
  ...
}:
let
  kittyConf = import ./kitty.nix;
in
{
  imports = [
    ./zsh.nix
    ./vim.nix
    ./yazi.nix
    (import ./waybar.nix { inherit config lib pkgs; })
    (import ./rofi.nix { inherit config lib pkgs; })
    ./ssh.nix
    ./desktop-entries.nix
    ./vm-connect.nix
  ];

  home = {
    username = "nx";
    homeDirectory = "/home/nx";
    sessionVariables.LANG = "en_US.UTF-8";
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    (writeShellScriptBin "nvim" ''
      #!${pkgs.bash}/bin/bash
      # This script acts as a wrapper to redirect `nvim` calls to the nvim MicroVM.
      # It passes all arguments it receives to the nvim_vm script.
      exec zsh -c 'source /home/nx/nixos-config/home/nvim.zsh; nvim_vm "$@"' _ "$@"
    '')
    oh-my-posh
    fastfetch
    # misc
    file
    tree

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    # strace # system call monitoring
    # ltrace # library call monitoring
    lsof # list open files
    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    nerd-fonts.fira-code
    chromium

    wl-screenrec

    wlogout
    dunst # notifications
    swaynotificationcenter

    rofimoji

    (import ./remote-zellij.nix { inherit pkgs; })
    (import ./backup.nix { inherit pkgs lib inputs; })
  ];

  # programs.direnv = {
  #   enable = true;
  #   nix-direnv.enable = true;
  # };

  # programs.kitty.enable = true;
  home.file.".config/kitty/kitty.conf" = {
    text = kittyConf;
    force = true;
  };
  home.file.".config/kitty/current-theme.conf".source = ./current-theme.conf;
  home.file.".config/kitty/startup".source = ./startup;

  # TODO: Debug whats going on when enabled
  # xdg.mimeApps.enable = lib.mkForce false;

  # zellij
  home.file.".config/zellij".source = ./zellij;

  # oh-my-posh theme
  home.file.".cache/oh-my-posh/themes/slimfat.omp.json".source = ./resources/slimfat.omp.json;

  xdg = {
    enable = true;

    portal = {
      enable = true;
      extraPortals = with pkgs; [
        pkgs.xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        xdg-desktop-portal
      ];
      xdgOpenUsePortal = true;
      configPackages = with pkgs; [
        pkgs.xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        xdg-desktop-portal
      ];
    };

    mimeApps = {
      enable = true;
    };

    # userDirs = {
    #   enable = true;
    #   createDirectories = true;
    #
    #   # Define standard XDG user directories
    #   desktop = "${config.home.homeDirectory}/Desktop";
    #   documents = "${config.home.homeDirectory}/Documents";
    #   download = "${config.home.homeDirectory}/Downloads";
    #   music = "${config.home.homeDirectory}/Music";
    #   pictures = "${config.home.homeDirectory}/Pictures";
    #   publicShare = "${config.home.homeDirectory}/Public";
    #   templates = "${config.home.homeDirectory}/Templates";
    #   videos = "${config.home.homeDirectory}/Videos";
    # };

    # Define standard XDG base directories
    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";
  };

  gtk = {
    enable = true;

    iconTheme = {
      name = "Tela-dark";
      package = pkgs.tela-icon-theme;
    };
  };
  # Set environment variables
  home.sessionVariables = {
    # Base XDG directories
    XDG_CACHE_HOME = config.xdg.cacheHome;
    XDG_CONFIG_HOME = config.xdg.configHome;
    XDG_DATA_HOME = config.xdg.dataHome;
    XDG_STATE_HOME = config.xdg.stateHome;
    XDG_RUNTIME_DIR = "/run/user/$(id -u)";

    # User directories
    XDG_DESKTOP_DIR = config.xdg.userDirs.desktop;
    XDG_DOCUMENTS_DIR = config.xdg.userDirs.documents;
    XDG_DOWNLOAD_DIR = config.xdg.userDirs.download;
    XDG_MUSIC_DIR = config.xdg.userDirs.music;
    XDG_PICTURES_DIR = config.xdg.userDirs.pictures;
    XDG_PUBLICSHARE_DIR = config.xdg.userDirs.publicShare;
    XDG_TEMPLATES_DIR = config.xdg.userDirs.templates;
    XDG_VIDEOS_DIR = config.xdg.userDirs.videos;

    # Additional XDG-related variables
    LESSHISTFILE = "/tmp/less-hist";
    PARALLEL_HOME = "${config.xdg.configHome}/parallel";
    SCREENRC = "${config.xdg.configHome}/screen/screenrc";
    ZSH_AUTOSUGGEST_STRATEGY = "history completion";

    # History configuration // explicit to not nuke history
    HISTFILE = "\${HISTFILE:-\$HOME/.zsh_history}";
    HISTSIZE = "10000";
    SAVEHIST = "10000";
    setopt_EXTENDED_HISTORY = "true";
    setopt_INC_APPEND_HISTORY = "true";
    setopt_SHARE_HISTORY = "true";
    setopt_HIST_EXPIRE_DUPS_FIRST = "true";
    setopt_HIST_IGNORE_DUPS = "true";
    setopt_HIST_IGNORE_ALL_DUPS = "true";
  };

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
      };

      # Window border colors
      "col.active_border" = "rgba(88c0d0ff)"; # aktive Fenster (helles Blau)
      "col.inactive_border" = "rgba(4c566a80)"; # inaktive Fenster (dunkler, halb transparent)

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        layout = "dwindle";
      };

      "$mod" = "SUPER";

      bind = [
        "$mod, A, exec, pkill rofi || rofi -show drun -theme ~/.config/rofi/theme.rasi"
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
        "$mod, comma, exec, rofimoji --selector-args='-theme ~/.config/rofi/theme.rasi'"
      ];

      bindl = [
        ",XF86MonBrightnessUp, exec, brightnessctl -d intel_backlight -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -d intel_backlight -e4 -n2 set 5%-"
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # Startup-Apps (Hyprland-Panel, Waybar, Notifier, etc.)
      exec-once = [
        "waybar"
        "systemctl --user restart wpaperd.service"
      ];

      bindm = [
        # Mausbewegungen
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
        "$mod ALT, mouse:272, resizewindow"
      ];

      # Window rules
      windowrule = [
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
      path = "${config.home.homeDirectory}/nixos-config/wallpapers/cat_lofi_cafe.jpg";
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
 
  home.stateVersion = "25.05";
}
