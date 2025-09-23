{ pkgs ? import <nixpkgs> {} }:

pkgs.symlinkJoin {
  name = "awrit";
  paths = [
    pkgs.electron
  ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/electron \
      --set QT_QPA_PLATFORM xcb \
      --set LD_LIBRARY_PATH ${pkgs.mesa}/lib:${pkgs.nss}/lib:${pkgs.nspr}/lib:${pkgs.glib}/lib:${pkgs.gtk3}/lib:${pkgs.pango}/lib:${pkgs.gdk-pixbuf}/lib:${pkgs.atk}/lib:${pkgs.at-spi2-atk}/lib:${pkgs.at-spi2-core}/lib:${pkgs.dbus}/lib:${pkgs.alsa-lib}/lib:${pkgs.cups}/lib:${pkgs.libdrm}/lib:${pkgs.libxkbcommon}/lib:${pkgs.expat}/lib:${pkgs.libuuid}/lib:${pkgs.libpulseaudio}/lib:${pkgs.libappindicator-gtk3}/lib:${pkgs.libnotify}/lib:${pkgs.libsecret}/lib:${pkgs.libusb1}/lib:${pkgs.xorg.libX11}/lib:${pkgs.xorg.libxcb}/lib:${pkgs.xorg.libXcomposite}/lib:${pkgs.xorg.libXdamage}/lib:${pkgs.xorg.libXext}/lib:${pkgs.xorg.libXfixes}/lib:${pkgs.xorg.libXi}/lib:${pkgs.xorg.libXrandr}/lib:${pkgs.xorg.libXScrnSaver}/lib:${pkgs.xorg.libXtst}/lib:${pkgs.xorg.xcbutil}/lib:${pkgs.xorg.xcbutilimage}/lib:${pkgs.xorg.xcbutilkeysyms}/lib:${pkgs.xorg.xcbutilrenderutil}/lib:${pkgs.xorg.xcbutilwm}/lib:${pkgs.xorg.libxkbfile}/lib:${pkgs.xorg.libICE}/lib:${pkgs.xorg.libSM}/lib:$LD_LIBRARY_PATH
  '';
}
