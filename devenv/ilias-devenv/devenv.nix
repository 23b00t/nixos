{
  pkgs,
  ...
}:

{
  # Grundlegende PHP-Konfiguration
  languages.php = {
    enable = true;
    version = "<PHP_VERSION>";
  };

  env.DBUI_URL="mariadb://ilias:homer@127.0.0.1:<MARIADB_PORT>/ilias";

  # PHP-Packages
  packages = with pkgs; [
    # Composer
    php<PHP_VERSION_NO_DOT>Packages.composer

    # PHP-Tools
    php<PHP_VERSION_NO_DOT>Packages.php-cs-fixer
    php<PHP_VERSION_NO_DOT>Packages.php-codesniffer
    intelephense
    vscode-langservers-extracted
    mariadb
  ];
  # Scripts
  scripts.cli.exec = "sudo docker exec -it <DIR_NAME> /bin/bash";
  scripts.ildb.exec = "sudo docker exec -it <DIR_NAME>_mariadb /bin/bash -c 'mariadb -h 127.0.0.1 -P <MARIADB_PORT> -u ilias -p'";
  scripts.up.exec = "sudo docker compose up";
  scripts.down.exec = "sudo docker compose down";
}
