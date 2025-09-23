{ pkgs, ... }:
{
  programs.nix-ld.dev = {
    enable = true;
    libraries = with pkgs; [
      # Grundlegende Entwicklungstools
      stdenv.cc.cc
      gcc
      glibc
      icu

      # Build-Tools
      gnumake
      cmake
      ninja

      # Sprachen & Laufzeitumgebungen
      nodejs
      nodePackages.npm
      python3
      python3Packages.pip

      # Werkzeuge für Mason
      unzip
      curl
      wget

      # Allgemeine Bibliotheken
      zlib
      openssl

      # LSP-spezifische Abhängigkeiten
      # Fügen Sie je nach Bedarf weitere hinzu
      llvmPackages.libclang
      llvmPackages.libcxx
    ];
  };

  # Alternativ, falls Sie die Systemversion von nix-ld verwenden:
  # programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [ ... ];

  # Umgebungsvariablen für bessere Kompatibilität
  environment.variables = {
    # Stellen Sie sicher, dass Mason temporäre Dateien an zugänglichen Orten speichert
    TMPDIR = "/tmp";
  };
}
