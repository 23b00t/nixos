{ lib, pkgs, ... }:
let
  phpToolPackages = import ./php/packages.nix { inherit pkgs; };

  phpShells = {
    "82" = phpToolPackages.php82-shell;
    "83" = phpToolPackages.php83-shell;
    "84" = phpToolPackages.php84-shell;
    "85" = phpToolPackages.php85-shell;
  };

  phpTools = [
    "php"
    "composer"
    "php-cs-fixer"
    "phpcs"
  ];

  mkRulesFor =
    ver: shell:
    [
      "d /home/user/bin/php${ver} 0755 user users -"
    ]
    ++ map (tool: "L+ /home/user/bin/php${ver}/${tool} - - - - ${shell}/bin/${tool}") phpTools;

  phpTmpfilesRules = [
    "d /home/user/bin 0755 user users -"
  ]
  ++ lib.flatten (lib.mapAttrsToList mkRulesFor phpShells);

  phpTmpfilesFile = pkgs.writeText "php-home-bin.conf" (
    lib.concatStringsSep "\n" phpTmpfilesRules + "\n"
  );
in
{
  services.common-config.browser = "firefox.desktop";

  services.zsh-env = {
    extraAliases = {
      il = "~/.config/zellij-layout/il-layout.sh";
    };
    extraShellInit = ''
      _ilias_cid() {
        local cid
        cid=$(sudo docker compose ps -q ilias)
        if [ -z "$cid" ]; then
          echo "No running 'ilias' container found." >&2
          return 1
        fi
        echo "$cid"
      }
      _mysql_cid() {
        local cid
        cid=$(sudo docker compose ps -q mysql)
        if [ -z "$cid" ]; then
          echo "No running 'mysql' container found." >&2
          return 1
        fi
        echo "$cid"
      }
      cli() {
        local cid
        cid="$(_ilias_cid)" || return 1
        sudo docker exec -it "$cid" /bin/bash
      }
      cdu() {
        local cid
        cid="$(_ilias_cid)" || return 1
        sudo docker exec -it "$cid" /bin/bash -c 'composer du'
      }
      ildb() {
        local cid
        cid="$(_mysql_cid)" || return 1
        sudo docker exec -it "$cid" /bin/bash -c 'mariadb -h 127.0.0.1 -P 3306 -u ilias -p'
      }
      log() {
        local cid
        cid="$(_ilias_cid)" || return 1
        sudo docker logs -f "$cid"
      }
      start() {
        sudo docker compose start
      }
      stop() {
        sudo docker compose stop
      }

    '';
  };

  services.zellij-env.tabsKdlFile = builtins.path {
    name = "tabs.kdl";
    path = ./php/tabs.kdl;
  };

  environment.etc."zellij-layout".source = ./php/zellij-layout;

  microvm.volumes = lib.mkAfter [
    {
      mountPoint = "/var";
      image = "var.img";
      size = 20000;
    }
  ];

  # Unfree, the user's own
  nox.unfree = [ "intelephense" ];

  environment.systemPackages =
    with pkgs;
    [
      phpstan
      intelephense
      vscode-langservers-extracted
      mariadb

      helix
      lazysql
      lazydocker
      scooter
      ec
      delta
    ]
    ++ builtins.attrValues phpToolPackages;

  programs.direnv.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      9003
    ];
    allowedTCPPortRanges = [
      {
        from = 8500;
        to = 8523;
      }
    ];
  };

  virtualisation.docker = {
    enable = true;
    extraOptions = "--experimental";
    extraPackages = [ pkgs.docker-buildx ];
    enableOnBoot = true;
    daemon.settings = {
      dns = [
        "8.8.8.8"
        "1.1.1.1"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "L+ /home/user/.config/zellij-layout - - - - /etc/zellij-layout"
  ];

  systemd.services.php-home-bin-tmpfiles = {
    description = "Create PHP tool symlinks in /home/user/bin after home mount";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    requires = [ "local-fs.target" ];
    unitConfig.RequiresMountsFor = [ "/home/user" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail
      ${pkgs.systemd}/bin/systemd-tmpfiles --create ${phpTmpfilesFile}
    '';
  };
}
