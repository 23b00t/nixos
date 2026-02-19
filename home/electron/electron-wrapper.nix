# Inspired by: https://discourse.nixos.org/t/how-to-wrap-all-my-electron-apps-with-args/17111/4
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
      --set LD_LIBRARY_PATH ${pkgs.mesa}/lib:${pkgs.nss}/lib:${pkgs.nspr}/lib:${pkgs.glib}/lib:${pkgs.gtk3}/lib:${pkgs.pango}/lib:${pkgs.gdk-pixbuf}/lib:${pkgs.atk}/lib:${pkgs.at-spi2-atk}/lib:${pkgs.at-spi2-core}/lib:${pkgs.dbus}/lib:${pkgs.alsa-lib}/lib:${pkgs.cups}/lib:${pkgs.libdrm}/lib:${pkgs.libxkbcommon}/lib:${pkgs.expat}/lib:${pkgs.libuuid}/lib:${pkgs.libpulseaudio}/lib:${pkgs.libappindicator-gtk3}/lib:${pkgs.libnotify}/lib:${pkgs.libsecret}/lib:${pkgs.libusb1}/lib:${pkgs.libx11}/lib:${pkgs.xorg.libxcb}/lib:${pkgs.libxcomposite}/lib:${pkgs.libxdamage}/lib:${pkgs.libxext}/lib:${pkgs.libxfixes}/lib:${pkgs.libxi}/lib:${pkgs.libxrandr}/lib:${pkgs.libxscrnsaver}/lib:${pkgs.libxtst}/lib:${pkgs.xorg.xcbutil}/lib:${pkgs.xorg.xcbutilimage}/lib:${pkgs.xorg.xcbutilkeysyms}/lib:${pkgs.xorg.xcbutilrenderutil}/lib:${pkgs.xorg.xcbutilwm}/lib:${pkgs.xorg.libxkbfile}/lib:${pkgs.xorg.libICE}/lib:${pkgs.xorg.libSM}/lib:$LD_LIBRARY_PATH
  '';
}
