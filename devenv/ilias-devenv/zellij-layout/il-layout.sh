#!/usr/bin/env bash

set -euo pipefail

read -rp "Enter ILIAS version: " IL_VERSION

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT_TEMPLATE="$SCRIPT_DIR/il-layout.kdl"
TEMP_LAYOUT="/tmp/il_dynamic.kdl"
BASE_DIR="$HOME/code/il_$IL_VERSION"

cp "$SCRIPT_DIR/il-layout.swap.kdl" "/tmp/il_dynamic.swap.kdl"

sed -e "s|{{BASE_PATH}}|$BASE_DIR|g" \
    -e "s|{{PROJECT_PATH}}|$BASE_DIR/ilias_$IL_VERSION|g" \
    -e "s|{{NAME}}|il_$IL_VERSION|g" \
    "$LAYOUT_TEMPLATE" > "$TEMP_LAYOUT"

zellij action new-tab --layout "$TEMP_LAYOUT"

