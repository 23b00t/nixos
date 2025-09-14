#!/usr/bin/env bash

set -euo pipefail

# Function to display usage information
usage() {
	echo "Usage: $0 <php_version> <mariadb_port> <destination_dir" 
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
  usage
  exit 1
fi

PHP_VERSION="$1"
MARIADB_PORT="$2"
PHP_VERSION_NO_DOT="${PHP_VERSION//./}"
ILIAS_DIR="${3:-$(pwd)}"
DIR_NAME=$(basename "$ILIAS_DIR")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initiate devenv
devenv init 

echo "Copying templates..."

# Copy devenv.nix and devenv.yaml to . 
cp "$SCRIPT_DIR/devenv.nix" "$ILIAS_DIR"
cp "$SCRIPT_DIR/devenv.yaml" "$ILIAS_DIR"
cp "$SCRIPT_DIR/phpcs.xml" "$ILIAS_DIR"
cp "$SCRIPT_DIR/phpstan.neon" "$ILIAS_DIR"
cp "$SCRIPT_DIR/constants.php" "$ILIAS_DIR"

echo "Customizing templates..."

# Replace placeholders in devenv.nix 
sed -i "s|<DIR_NAME>|$DIR_NAME|g" devenv.nix
sed -i "s|<PHP_VERSION>|$PHP_VERSION|g" devenv.nix
sed -i "s|<PHP_VERSION_NO_DOT>|$PHP_VERSION_NO_DOT|g" devenv.nix
sed -i "s|<MARIADB_PORT>|$MARIADB_PORT|g" devenv.nix

echo "Finished setting up the ILIAS development environment."
