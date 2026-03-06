{
  # In this example, index 5, we need to run:
  # sudo ip tuntap add vm5 mode tap user nx
  # to get the tap device working rootless.
  description = "nvim MicroVM";

  inputs.microvm = {
    url = "github:astro/microvm.nix";
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
      index = 1;
      mac = "00:00:00:00:00:01";
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
            (import ../net-config.nix { inherit lib index mac; })
            (import ../common-config.nix {
              inherit lib;
              inherit pkgs;
              sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzJjZw0V2CdaWI/IBFcTQPwQhYtFn/31i5iNPSc1j8G nvim-vm";
            })
            (import ../yazi-config.nix { inherit pkgs; })
            ../modules/ide.nix
            ../modules/zsh.nix
            ../modules/zellij.nix
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
                nixOverlayBackupScript = pkgs.writeShellScriptBin "nix-overlay-backup" ''
                   #!/usr/bin/env bash
                  set -euo pipefail
                  UPPERDIR="/nix/.rw-store/store"
                  CACHEDIR="/mnt/store-cache"

                  find "$UPPERDIR" -mindepth 1 -maxdepth 1 -type d -printf "/nix/store/%f\n" > /tmp/overlay-paths.txt
                  if [ -s /tmp/overlay-paths.txt ]; then
                    xargs /run/current-system/sw/bin/nix copy --no-check-sigs --to "file://$CACHEDIR" < /tmp/overlay-paths.txt
                  fi
                '';
              in
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "nvim-vm";

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  writableStoreOverlay = "/nix/.rw-store";
                  preStart = ''
                    rm -f nix-store-overlay.img
                  '';
                  # storeOnDisk = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 80000;
                    }
                    # {
                    #   mountPoint = "/nix/store";
                    #   image = "nix-store.img";
                    #   label = "nix-store";
                    #   size = 60000;
                    # }
                    {
                      mountPoint = "/mnt/store-cache";
                      image = "store-cache.img";
                      size = 50000;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 50000;
                    }
                  ];
                  shares = [
                    {
                      proto = "virtiofs";
                      tag = "host-home";
                      source = "/home/nx";
                      mountPoint = "/mnt/host";
                    }
                    {
                      proto = "virtiofs";
                      tag = "ro-store";
                      source = "/nix/store";
                      mountPoint = "/nix/.ro-store";
                    }
                  ];
                  mem = 8192;
                  vcpu = 8;
                };

                environment.systemPackages =
                  with pkgs;
                  [
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

                    pulseaudio
                    termdown

                  ]
                  ++ defaultPkgs;

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

                services.ide = {
                  enable = true;
                  lazyvimRepo = "git@github.com:23b00t/lazyvim.git";
                };

                services.zellij-env = {
                  enable = true;
                  # Defaults for reference
                  # user = "user";
                  # configDir = ./zellij-custom;
                };

                services.zsh-env = {
                  enable = true;
                  # Defaults for reference
                  # user = "user";
                  # ohMyPoshTheme = "montys.omp.json";

                  extraAliases = {
                    edit = "sudo -e";
                    dc = "docker compose";
                    ilinit = "$HOME/code/devenv/ilias-devenv/ilias-devenv-builder.sh";
                  };

                  extraShellInit = ''
                    # Countdown shell function
                    countdown() {
                      termdown "$1" -c 10 && paplay --volume=43000 ~/Music/airhorn.wav
                    }
                  '';
                };

                environment.etc = {
                  "nix-overlay-backup".source = "${nixOverlayBackupScript}/bin/nix-overlay-backup";
                };

                systemd.services.nix-overlay-backup = {
                  description = "Export Nix store paths from writable overlay to store cache on shutdown";
                  script = "/etc/nix-overlay-backup";
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    DefaultDependencies = false;
                    Before = [
                      "umount.target"
                      "poweroff.target"
                      "reboot.target"
                      "halt.target"
                    ];
                    TimeoutSec = 0;
                  };
                  wantedBy = [
                    "poweroff.target"
                    "halt.target"
                    "reboot.target"
                  ];
                };

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

                nix = {
                  settings = {
                    substituters = [
                      "file:///mnt/store-cache"
                      "https://cache.nixos.org"
                      "https://microvm.cachix.org"
                    ];
                    trusted-public-keys = [
                      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                      "microvm.cachix.org-1:oXnBs9THCoQI4PiXLm2ODWyptDIrQ2NYjmJfUfpGqMI="
                    ];
                    trusted-users = [
                      "root"
                      "user"
                    ];
                    extra-experimental-features = [
                      "nix-command"
                      "flakes"
                    ];
                  };
                };

                # For termusic
                environment.variables = {
                  PULSE_SERVER = "tcp:localhost:4713";
                };

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
