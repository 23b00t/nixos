{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    rofi # application launcher
  ];

  home.file = {
    # stateful file, written by wallbash
    # .local/share/hyde/wallbash/theme/rofi.dcol
    ".config/rofi/theme.rasi" = {
      source = "${pkgs.hyde}/Configs/.config/rofi/theme.rasi";
      force = true;
    };
  };

  home.activation.hydeRofiThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.local/share/rofi/themes"
    $DRY_RUN_CMD find "$HOME/.local/share/hyde/rofi/themes" -type f -o -type l -exec ln -snf {} "$HOME/.local/share/rofi/themes/" \; 2>/dev/null || true
  '';

  home.file = {
    ".local/share/hyde/rofi/assets/" = {
      source = "${pkgs.hyde}/Configs/.local/share/hyde/rofi/assets/";
      recursive = true;
      force = true;
    };

    ".local/share/hyde/rofi/themes/" = {
      source = "${pkgs.hyde}/Configs/.local/share/hyde/rofi/themes/";
      recursive = true;
      force = true;
    };
  };
}
