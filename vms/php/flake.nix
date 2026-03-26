{
  description = "php MicroVM";

  inputs = {
    microvm = {
      url = "github:astro/microvm.nix";
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
      index = 15;
      mac = "00:00:00:00:00:0f";
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
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHpfcEv27hamz0HELXGKpLd6M+/m5m/fopZ3A7fonUVw php-vm";
            })
            ../modules/ide.nix
            ../modules/zsh.nix
            ../modules/zellij.nix
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
                phpSwitcherScript = import ./php-switcher.nix;
                phpSwitcherBin = pkgs.writeShellScriptBin "setphpv" phpSwitcherScript;
              in
              {
                networking.hostName = "php-vm";
                services.ide.enable = true;
                services.zsh-env.enable = true;
                services.zellij-env = {
                  enable = true;
                  tabsKdlFile = builtins.path {
                    name = "tabs.kdl";
                    path = ./tabs.kdl;
                  };
                };

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

                  mem = 8192;
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
                  ++ defaultPkgs
                  ++ [
                    self.packages.${pkgs.system}.php82-shell
                    self.packages.${pkgs.system}.php83-shell
                    self.packages.${pkgs.system}.php84-shell
                    self.packages.${pkgs.system}.php85-shell
                    phpSwitcherBin
                  ];

                networking.firewall = {
                  enable = true;
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

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
