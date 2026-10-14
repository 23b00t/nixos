# Central desktop theme (Tokyo Night): colors, transparency, radii and fonts
# for niri, waybar, rofi, swaync and swaylock.
# Usage: `theme = import ./theme.nix { inherit lib; };`
{ lib }:
let
  # Tokyo Night palette, hex without '#'
  palette = {
    bg = "24283b"; # storm background
    bgDark = "1a1b26"; # night background
    fg = "c0caf5";
    comment = "565f89";
    border = "3b4261";
    blue = "7aa2f7";
    cyan = "7dcfff";
    teal = "b4f9f8";
    magenta = "bb9af7";
    lavender = "d1bfff";
    red = "f7768e";
    yellow = "e0af68";
    green = "9ece6a";
    black = "000000";
  };

  # 0.0-1.0 -> two hex digits
  alphaHex =
    a: lib.toLower (lib.fixedWidthString 2 "0" (lib.toHexString (builtins.floor (a * 255 + 0.5))));
in
rec {
  inherit palette;

  # Semantic roles, hex without '#' (swaylock wants it that way)
  raw = {
    inherit (palette) bg bgDark border;
    fg = palette.blue; # text everywhere, as waybar always had it
    fgActive = palette.teal; # text on accent backgrounds
    accent = palette.magenta; # focus ring, active workspace, selection
    accent2 = palette.blue; # second gradient stop, selection background
    inactive = palette.lavender;
    muted = palette.comment;
    urgent = palette.red;
    warn = palette.yellow;
    ok = palette.green;
    info = palette.cyan;
    shadow = palette.black;
  };

  # Same roles as "#rrggbb" for CSS, KDL and rasi
  color = lib.mapAttrs (_: c: "#${c}") raw;

  # Transparency levels
  opacity = {
    surface = 0.8; # waybar modules, notifications
    popup = 0.9; # rofi
    bar = 0.1; # waybar background (on black)
    shadow = 0.44;
    inactiveRing = 0.8;
  };

  # "#rrggbbaa" / "rrggbbaa" from a role name and an opacity
  withAlpha = role: a: "${color.${role}}${alphaHex a}";
  rawWithAlpha = role: a: "${raw.${role}}${alphaHex a}";

  # Corner radii in px; `radius` matches niri's geometry-corner-radius
  radius = 10;
  radiusInner = 6;

  font = {
    family = "FiraCode Nerd Font";
    barSize = 14; # px, waybar
    launcherSize = 11; # pt, rofi
    lockSize = 24; # px, swaylock
  };

  # Icon theme for GTK/Qt and rofi; package: tela-circle-icon-theme with this variant
  icons = {
    name = "Tela-circle-dracula";
    variant = "dracula";
  };

  wallpaper = {
    lock = ./wallpapers/cat_lofi_cafe.jpg;
  };
}
