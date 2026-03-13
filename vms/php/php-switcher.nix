let
  phpSwitcherScript = ''
    #!/usr/bin/env bash
    set -e

    if [ -z "$1" ]; then
      echo "Usage: setphpv <82|83|84|85>"
      exit 1
    fi

    PHP_VER="$1"

    # Find the correct store path
    PHP_STORE=$(ls /nix/store | grep "php${PHP_VER}-shell" | head -n1)
    if [ -z "$PHP_STORE" ]; then
      echo "PHP$PHP_VER environment not found in /nix/store"
      exit 1
    fi

    # Create ~/bin if it doesn't exist
    mkdir -p ~/bin

    # Overwrite symlinks in ~/bin
    ln -sf "/nix/store/$PHP_STORE/bin/php" ~/bin/php
    ln -sf "/nix/store/$PHP_STORE/bin/composer" ~/bin/composer
    ln -sf "/nix/store/$PHP_STORE/bin/php-cs-fixer" ~/bin/php-cs-fixer
    ln -sf "/nix/store/$PHP_STORE/bin/phpcs" ~/bin/phpcs

    echo "Switched to PHP $PHP_VER"
  '';
in
phpSwitcherScript
