{
  config,
  pkgs,
  ...
}:
{
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
      defaultApplications = {
        # Images
        "image/png" = "satty.desktop";
        "image/jpeg" = "satty.desktop";
        "image/jpg" = "satty.desktop";
        "image/webp" = "satty.desktop";
        "image/gif" = "satty.desktop";

        # Videos
        "video/mp4" = "chromium-browser.desktop";
        "video/webm" = "chromium-browser.desktop";
        "video/x-matroska" = "chromium-browser.desktop";
        "video/ogg" = "chromium-browser.desktop";
        "video/quicktime" = "chromium-browser.desktop";
        "video/x-msvideo" = "chromium-browser.desktop";
        "video/x-flv" = "chromium-browser.desktop";
        "video/x-ms-wmv" = "chromium-browser.desktop";
        "video/mpeg" = "chromium-browser.desktop";
        "video/3gpp" = "chromium-browser.desktop";
        "video/3gpp2" = "chromium-browser.desktop";

        # URLs
        "x-scheme-handler/http" = "zen.desktop";
        "x-scheme-handler/https" = "zen.desktop";
        "x-scheme-handler/about" = "zen.desktop";
        "x-scheme-handler/unknown" = "zen.desktop";
      };
    };

    # Define standard XDG base directories
    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";
  };

  environment.etc."xdg/mimeapps.list".text = ''
    [Default Applications]
    x-scheme-handler/http=zen.desktop
    x-scheme-handler/https=zen.desktop
    x-scheme-handler/about=zen.desktop
    x-scheme-handler/unknown=zen.desktop
  '';

  gtk = {
    enable = true;

    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name = "Tela-dark";
      package = pkgs.tela-icon-theme;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style = {
      name = "kvantum";
      package = pkgs.libsForQt5.qtstyleplugin-kvantum;
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

    QT_QPA_PLATFORMTHEME = "gtk2";
    QT_STYLE_OVERRIDE = "kvantum";
    GTK_THEME = "Adwaita:dark";
  };

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=KvAdaptaDark
  '';

  xdg.configFile."Kvantum/KvAdaptaDark/KvAdaptaDark.kvconfig".source =
    "${pkgs.libsForQt5.qtstyleplugin-kvantum}/share/Kvantum/KvAdaptaDark/KvAdaptaDark.kvconfig";
}
