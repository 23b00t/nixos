#!/usr/bin/env bash

set -euo pipefail

# Function to display usage information
usage() {
	echo "Usage: $0 <ilias_dir> <php_version> <mariadb_port>"
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
  usage
  exit 1
fi

ILIAS_DIR="$1"
PHP_VERSION="$2"
MARIADB_PORT="$3"
PHP_VERSION_NO_DOT="${PHP_VERSION//./}"

# Initiate devenv
devenv init 

echo "Copying templates..."

# Copy devenv.nix and devenv.yaml to . 
cp "$HOME/Documents/ilias-devenv/devenv.nix" .
cp "$HOME/Documents/ilias-devenv/devenv.yaml" .
cp "$HOME/Documents/ilias-devenv/phpcs.xml" .
cp "$HOME/Documents/ilias-devenv/phpstan.neon" .
cp "$HOME/Documents/ilias-devenv/constants.php" .

echo "Customizing templates..."

# Replace placeholders in devenv.nix 
sed -i "s|<ILIAS_DIR>|$ILIAS_DIR|g" devenv.nix
sed -i "s|<PHP_VERSION>|$PHP_VERSION|g" devenv.nix
sed -i "s|<PHP_VERSION_NO_DOT>|$PHP_VERSION_NO_DOT|g" devenv.nix
sed -i "s|<MARIADB_PORT>|$MARIADB_PORT|g" devenv.nix

echo "Finished setting up the ILIAS development environment."
