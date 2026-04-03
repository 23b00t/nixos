#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <ILIAS_BASE_FOLDER aka ~/code/il_VERSION_OR_NAME>"
    exit 1
fi

IL_VERSION="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT_TEMPLATE="$SCRIPT_DIR/il-layout.kdl"
TEMP_LAYOUT="/tmp/il_dynamic.kdl"
BASE_DIR="$HOME/code/il_$IL_VERSION"
MAIN_VERSION="${IL_VERSION%%_*}"

sed -e "s|{{BASE_PATH}}|$BASE_DIR|g" \
    -e "s|{{PROJECT_PATH}}|$BASE_DIR/ilias_$MAIN_VERSION|g" \
    -e "s|{{NAME}}|il_$IL_VERSION|g" \
    "$LAYOUT_TEMPLATE" > "$TEMP_LAYOUT"

zellij action new-tab --layout "$TEMP_LAYOUT"
