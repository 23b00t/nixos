{
  config,
  lib,
  pkgs,
  ...
}:
let
  hydeOverlay = final: prev: {
    hyde = prev.stdenv.mkDerivation {
      pname = "hyde";
      version = "unstable-2026-04-15";
      src = prev.fetchFromGitHub {
        owner = "HyDE-Project";
        repo = "HyDE";
        rev = "master";
        sha256 = "0000000000000000000000000000000000000000000000000000"; # <-- sha256 ersetzen!
      };
      installPhase = ''
        mkdir -p $out
        cp -r Configs $out/
      '';
    };
  };
  pkgs = import pkgs.path {
    overlays = [ hydeOverlay ];
    config = config.nixpkgs.config or { };
  };
in
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
      mutable = true;
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
      mutable = true;
    };

    ".local/share/hyde/rofi/themes/" = {
      source = "${pkgs.hyde}/Configs/.local/share/hyde/rofi/themes/";
      recursive = true;
      force = true;
      mutable = true;
    };
  };
}
