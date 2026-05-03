{ pkgs }:
{
  php82-shell = pkgs.buildEnv {
    name = "php82-shell";
    paths = with pkgs; [
      php82
      php82Packages.composer
      php82Packages.php-cs-fixer
      php82Packages.php-codesniffer
    ];
  };

  php83-shell = pkgs.buildEnv {
    name = "php83-shell";
    paths = with pkgs; [
      php83
      php83Packages.composer
      php83Packages.php-cs-fixer
      php83Packages.php-codesniffer
    ];
  };

  php84-shell = pkgs.buildEnv {
    name = "php84-shell";
    paths = with pkgs; [
      php84
      php84Packages.composer
      php84Packages.php-cs-fixer
      php84Packages.php-codesniffer
    ];
  };

  php85-shell = pkgs.buildEnv {
    name = "php85-shell";
    paths = with pkgs; [
      php85
      php85Packages.composer
      php85Packages.php-cs-fixer
      php85Packages.php-codesniffer
    ];
  };
}
