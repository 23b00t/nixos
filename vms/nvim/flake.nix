{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "nvim MicroVM";

  inputs.microvm = {
    url = "github:microvm-nix/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
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
        default = self.packages.${system}.nvim;
        nvim = self.nixosConfigurations.nvim.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        nvim = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ../modules/net-config.nix
            ../modules/yazi-config.nix
            ../modules/ide.nix
            ../modules/zsh.nix
            ../modules/zellij.nix
            ../modules/persistent-store-overlay.nix
            ../modules/common-config.nix
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "nvim-vm";

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 80000;
                    }
                  ];
                  shares = [
                    {
                      proto = "virtiofs";
                      tag = "host-home";
                      source = "/home/nx";
                      mountPoint = "/mnt/host";
                    }
                  ];
                  mem = 8192;
                  vcpu = 4;
                };

                environment.systemPackages = with pkgs; [
                  lua-language-server
                  lua51Packages.lua
                  lua51Packages.luarocks
                  nixfmt

                  ddate
                  cowsay

                  postman
                  dbeaver-bin
                  devenv
                  firefox

                  wprs
                  xwayland
                  ruby

                  pulseaudio
                  termdown
                ];

                networking.firewall = {
                  enable = true;
                  allowedTCPPorts = [
                    8080
                    8082
                    3000
                  ];
                  allowedTCPPortRanges = [
                    {
                      from = 8500;
                      to = 8523;
                    }
                  ];
                };

                # direnv
                programs.direnv = {
                  enable = true;
                  nix-direnv.enable = true;
                };

                services.net-config = {
                  enable = true;
                  index = 1;
                  mac = "00:00:00:00:00:01";
                };
                services.common-config = {
                  enable = true;
                  
                };

                services.ide = {
                  enable = true;
                  githubAgent.enable = true;
                  lazyvimRepo = "git@github.com:23b00t/lazyvim.git";
                };

                services.zellij-env = {
                  enable = true;
                  # Defaults for reference
                  # user = "user";
                  # configDir = ./zellij-custom;
                  tabsKdlFile = builtins.path {
                    name = "tabs.kdl";
                    path = ./tabs.kdl;
                  };
                };

                services.zsh-env = {
                  enable = true;
                  # Defaults for reference
                  # user = "user";
                  ohMyPoshTheme = "1_shell.omp.json";

                  extraAliases = {
                    edit = "sudo -e";
                    dc = "docker compose";
                  };

                  extraShellInit = ''
                    # Countdown shell function
                    countdown() {
                      termdown "$1" -c 10 && paplay --volume=43000 ~/Music/airhorn.wav
                    }
                  '';
                };

                services.persistentStoreOverlay.enable = true;

                virtualisation = {
                  docker = {
                    enable = true;
                    # Für rootless Docker (optional)
                    # rootless = {
                    #   enable = true;
                    #   setSocketVariable = true;
                    # };
                    # BuildX-Plugin aktivieren
                    # enableOnBoot = true; # Docker beim Systemstart starten
                    extraOptions = "--experimental"; # Experimentelle Features aktivieren
                    extraPackages = [ pkgs.docker-buildx ]; # BuildX-Plugin hinzufügen
                  };
                  podman = {
                    enable = true;
                    # Keine Docker-Kompatibilität, wenn Docker selbst installiert ist
                    dockerCompat = false;
                  };
                };

                systemd.user.services.wprsd = {
                  description = "wprsd instance";
                  after = [ "network.target" ];
                  serviceConfig = {
                    Type = "simple";
                    Environment = [
                      "PATH=/run/current-system/sw/bin"
                      "RUST_BACKTRACE=1"
                    ];
                    ExecStart = "/run/current-system/sw/bin/wprsd";
                  };
                  wantedBy = [ "default.target" ];
                };

                environment.variables = {
                  PULSE_SERVER = "tcp:localhost:4713";
                };

                system.stateVersion = "26.05";
              }
            )
          ];
        };
      };
    };
}
