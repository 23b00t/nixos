{
  description = "ruby MicroVM";

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
      index = 16;
      mac = "00:00:00:00:00:10";
    in
    {
      nixosConfigurations = {
        ruby = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAkF7qniIZVKtoIrUUWkU8t/1QeK34BSEgI54MbqbieC ruby-vm";
            })
            (import ../yazi-config.nix { inherit pkgs; })
            ../modules/ide.nix
            ../modules/zsh.nix
            ../modules/zellij.nix
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
              in
              {
                networking.hostName = "ruby-vm";
                services.ide.enable = true;
                services.zsh-env = {
                  enable = true;
                  extraShellInit = ''
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
                      size = 10000;
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

                  mem = 12288;
                  vcpu = 2;
                };

                environment.systemPackages =
                  with pkgs;
                  [
                    libyaml
                    gcc
                    cmake
                    pkg-config
                    zlib
                    yarn
                    postgresql
                    sqlite
                    bundler
                    nodejs
                    imagemagick
                    libffi
                    libxml2
                    libxslt
                    openssl
                    wkhtmltopdf
                    watchman
                    rbenv
                  ]
                  ++ defaultPkgs;

                programs.direnv.enable = true;

                networking.firewall = {
                  enable = true;
                  allowedTCPPorts = [
                    3000
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

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
