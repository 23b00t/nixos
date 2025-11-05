#!/usr/bin/env bash
# Run termdown countdown with nix shell and play sound after it

arg="$1"

nix shell "nixpkgs#termdown" "nixpkgs#pulseaudio" --command bash -c "
  termdown \"$arg\" -c 10 && paplay --volume=43000 ~/Music/airhorn.wav
"
