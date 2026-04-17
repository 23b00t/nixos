{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    kdePackages.qt6ct
    nwg-look
    libsForQt5.qtstyleplugin-kvantum
    libsForQt5.qt5ct
    gtk3
    gtk4
    gsettings-desktop-schemas
    tela-icon-theme
  ];

  home.file = {
    # QT6 Theme
    ".config/qt6ct/qt6ct.conf".text = ''
      [Appearance]
      color_scheme_path=
      custom_palette=false
      icon_theme=Tela-dark
      style=kvantum-dark
    '';

    # QT5 Theme (optional)
    ".config/qt5ct/qt5ct.conf".text = ''
      [Appearance]
      icon_theme=Tela-dark
      style=kvantum-dark
    '';

    # Kvantum Theme (für Blur und Transparenz)
    ".config/Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=KvArcDark
    '';
    ".config/Kvantum/KvArcDark/KvArcDark.kvconfig".text = ''
      [General]
      translucency=true
      menu_blur=true
    '';

    # GTK3 Theme
    ".config/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-theme-name=Adwaita-dark
      gtk-icon-theme-name=Tela-dark
      gtk-font-name=Fira Sans 10
      gtk-application-prefer-dark-theme=1
    '';

    # GTK4 Theme (optional)
    ".config/gtk-4.0/settings.ini".text = ''
      [Settings]
      gtk-theme-name=Adwaita-dark
      gtk-icon-theme-name=Tela-dark
      gtk-font-name=Fira Sans 10
      gtk-application-prefer-dark-theme=1
    '';

    # nwg-look config (GTK Theme Tool)
    ".config/nwg-look/config".text = ''
      theme=Adwaita-dark
      icon_theme=Tela-dark
      font=Fira Sans 10
    '';

    # xsettingsd für GTK/Firefox Theme-Übernahme (optional)
    ".config/xsettingsd/xsettingsd.conf".text = ''
      Net/ThemeName "Adwaita-dark"
      Net/IconThemeName "Tela-dark"
      Gtk/FontName "Fira Sans 10"
    '';
  };
}
