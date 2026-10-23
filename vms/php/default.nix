{ lib, pkgs, inputs, ... }:
let
  phpToolPackages = import ./packages.nix { inherit pkgs; };

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
  imports = [
    (inputs.nox.lib.vms + "/modules/net-config.nix")
    (inputs.nox.lib.vms + "/modules/yazi-config.nix")
    (inputs.nox.lib.vms + "/modules/ide.nix")
    (inputs.nox.lib.vms + "/modules/zsh.nix")
    (inputs.nox.lib.vms + "/modules/zellij.nix")
    (inputs.nox.lib.vms + "/modules/common-config.nix")
  ];

  networking.hostName = "php-vm";

  services.net-config = {
    enable = true;
    index = 15;
    mac = "00:00:00:00:00:0f";
  };

  services.common-config = {
    enable = true;
    # PDFs and images open there (xdg-open, e.g. from yazi)
    browser = "firefox.desktop";
  };

  services.ide = {
    enable = true;
    githubAgent.enable = true;
  };

  services.zsh-env = {
    enable = true;
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

  services.zellij-env = {
    enable = true;
    tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./tabs.kdl;
    };
  };

  environment.etc."zellij-layout".source = ./zellij-layout;

  microvm = {

    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 25000;
      }
      {
        mountPoint = "/var";
        image = "var.img";
        size = 20000;
      }
    ];

    # Boots with 4096 MB, the RAM balancer grows it up to 16384 MB
    mem = 16384;
    balloon = true;
    initialBalloonMem = 4096;
    vcpu = 2;
  };

  environment.systemPackages =
    with pkgs;
    [
      # Unfree, the user's own (no longer from NoX ide.nix)
      claude-code
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

      # Testing the web apps (User 2026-10-22)
      firefox
      chromium
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

  system.stateVersion = "26.05";
}
