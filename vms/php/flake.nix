{
  description = "php MicroVM";

  inputs = {
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        default = self.packages.${system}.php;
        php = self.nixosConfigurations.php.config.microvm.declaredRunner;

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
      };
      nixosConfigurations = {
        php = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/yazi-config.nix
            ../modules/ide.nix
            ../modules/zsh.nix
            ../modules/zellij.nix
            ../modules/common-config.nix
            (
              { config, pkgs, ... }:
              let
                phpShells = {
                  "82" = self.packages.${pkgs.stdenv.hostPlatform.system}.php82-shell;
                  "83" = self.packages.${pkgs.stdenv.hostPlatform.system}.php83-shell;
                  "84" = self.packages.${pkgs.stdenv.hostPlatform.system}.php84-shell;
                  "85" = self.packages.${pkgs.stdenv.hostPlatform.system}.php85-shell;
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
                  # critical: avoid unsafe path transition by ensuring /home/user/bin is user-owned
                  "d /home/user/bin 0755 user users -"
                ]
                ++ lib.flatten (lib.mapAttrsToList mkRulesFor phpShells);

                phpTmpfilesFile = pkgs.writeText "php-home-bin.conf" (
                  lib.concatStringsSep "\n" phpTmpfilesRules + "\n"
                );
              in
              {
                networking.hostName = "php-vm";

                services.net-config = {
                  enable = true;
                  index = 15;
                  mac = "00:00:00:00:00:0f";
                };
                services.common-config = {
                  enable = true;
                  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHpfcEv27hamz0HELXGKpLd6M+/m5m/fopZ3A7fonUVw php-vm";
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
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
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
                  shares = [
                    {
                      proto = "virtiofs";
                      tag = "ro-store";
                      source = "/nix/store";
                      mountPoint = "/nix/.ro-store";
                    }
                  ];

                  mem = 16384;
                  vcpu = 2;
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    phpstan
                    intelephense
                    vscode-langservers-extracted
                    mariadb
                  ]
                  ++ [
                    self.packages.${pkgs.stdenv.hostPlatform.system}.php82-shell
                    self.packages.${pkgs.stdenv.hostPlatform.system}.php83-shell
                    self.packages.${pkgs.stdenv.hostPlatform.system}.php84-shell
                    self.packages.${pkgs.stdenv.hostPlatform.system}.php85-shell
                  ];

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

                virtualisation = {
                  docker = {
                    enable = true;
                    # rootless = {
                    #   enable = true;
                    #   setSocketVariable = true;
                    # };
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
                };

                systemd.tmpfiles.rules = [
                  # zellij layout for ILIAS
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
            )
          ];
        };
      };
    };
}
