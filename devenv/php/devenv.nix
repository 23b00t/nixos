{
  pkgs,
  lib,
  config,
  ...
}:

{
  # Grundlegende PHP-Konfiguration
  languages.php = {
    enable = true;
    version = "8.2";
    # extensions = [
    #   "pdo"
    #   "pdo_mysql"
    #   "mysqli"
    #   "intl"
    #   "mbstring"
    #   "xml"
    #   "zip"
    # ];
    # ini = ''
    #   memory_limit = 256M
    #   date.timezone = Europe/Berlin
    #   display_errors = On
    #   error_reporting = E_ALL
    # '';
  };

  # PHP-Packages
  packages = with pkgs; [
    # Composer
    php82Packages.composer

    # PHP-Tools
    php82Packages.php-cs-fixer
    php82Packages.phpstan
    intelephense
    vscode-langservers-extracted
  ];

  # Services
  services.mysql = {
    enable = true;
    package = pkgs.mysql80;
    initialDatabases = [ { name = "app"; } ];
    ensureUsers = [
      {
        name = "dev";
        password = "dev";
        ensurePermissions = {
          "app.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  services.nginx = {
    enable = true;
    httpConfig = ''
      server {
        listen 2323;  # Höherer Port um Berechtigungsprobleme zu vermeiden
        server_name localhost;
        
        root ${config.env.DEVENV_ROOT}/public;
        index index.php index.html;
        
        # Debugging für 502 Bad Gateway
        error_log /tmp/nginx-error.log debug;
        access_log /tmp/nginx-access.log;
        
        location / {
          try_files $uri $uri/ /index.php$is_args$args;
        }
        
        location ~ \.php$ {
          fastcgi_pass 127.0.0.1:9000;  # Stellen Sie sicher, dass PHP-FPM auf diesem Port läuft
          fastcgi_index index.php;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_read_timeout 300;
        }
      }
    '';
  };

  # PHP-FPM manuell starten
  processes.php-fpm.exec = "${pkgs.php82}/bin/php-fpm -F -y ${config.env.DEVENV_ROOT}/php-fpm.conf";

  # Scripts
  scripts.install-composer-deps.exec = "composer install";
  scripts.install-captainhook.exec = "composer require --dev captainhook/captainhook";
  scripts.install-phpcs.exec = "composer require --dev squizlabs/php_codesniffer";
  scripts.setup-php-fpm.exec = ''
    cat > php-fpm.conf << EOF
    [global]
    error_log = /tmp/php-fpm-error.log
    daemonize = no

    [www]
    user = $(whoami)
    group = $(id -gn)
    listen = 127.0.0.1:9000
    listen.owner = $(whoami)
    listen.group = $(id -gn)
    pm = dynamic
    pm.max_children = 5
    pm.start_servers = 2
    pm.min_spare_servers = 1
    pm.max_spare_servers = 3
    EOF
    echo "PHP-FPM Konfiguration wurde erstellt. Starten Sie devenv neu."
  '';

  # Startup-Informationen
  enterShell = ''
    echo "PHP development environment ready!"
    php -v
    echo "Available commands:"
    echo "  - install-composer-deps: Install Composer dependencies"
    echo "  - install-captainhook: Install CaptainHook"
    echo "  - install-phpcs: Install PHP CodeSniffer"
    echo "  - setup-php-fpm: Create PHP-FPM configuration"

    # Prüfen, ob die PHP-FPM Konfiguration existiert
    if [ ! -f "php-fpm.conf" ]; then
      echo "WICHTIG: Führen Sie 'setup-php-fpm' aus, um die PHP-FPM Konfiguration zu erstellen!"
    fi
  '';
}
