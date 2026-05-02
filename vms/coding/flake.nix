{
  description = "coding MicroVM";

  inputs.microvm = {
    url = "github:microvm-nix/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.coding;
        coding = self.nixosConfigurations.coding.config.microvm.declaredRunner;
      };

      nixosConfigurations.coding = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          ../modules/net-config.nix
          ../modules/common-config.nix
          ../modules/ide.nix
          ../modules/zsh.nix
          ../modules/zellij.nix
          ../modules/persistent-store-overlay.nix
          ../modules/wprs.nix
          ../modules/yazi-config.nix
          (
            { pkgs, ... }:
            {
              nixpkgs.config.allowUnfree = true;
              networking.hostName = "coding-vm";

              microvm = {
                registerClosure = false;
                hypervisor = "cloud-hypervisor";
                volumes = [
                  {
                    mountPoint = "/home/user";
                    image = "home.img";
                    size = 70000;
                  }
                ];
                mem = 8192;
                vcpu = 4;
              };

              services = {
                persistentStoreOverlay.enable = true;

                net-config = {
                  enable = true;
                  index = 6;
                  mac = "00:00:00:00:00:06";
                };

                common-config.enable = true;

                ide = {
                  enable = true;
                  githubAgent.enable = true;
                };

                zsh-env = {
                  enable = true;
                  extraAliases = {
                    dc = "docker compose";
                    cmd = "eval $(fzf < ~/cmds)";
                    pcmd = "cmd=$(fzf < ~/cmds); vared -p '> ' -c cmd; eval '$cmd'";
                  };
                  extraShellInit = ''
                    # Countdown shell function
                    countdown() {
                      termdown "$1" -c 10 && paplay --volume=43000 ~/Music/airhorn.wav
                    }
                  [ -f "$HOME/paste_functions.zsh" ] && source "$HOME/paste_functions.zsh"
                  '';
                };

                zellij-env = {
                  enable = true;
                  tabsKdlFile = builtins.path {
                    name = "tabs.kdl";
                    path = ./tabs.kdl;
                  };
                };
              };

              networking.firewall = {
                enable = true;
                allowedTCPPorts = [
                  8080
                ];
              };

              # direnv
              programs.direnv = {
                enable = true;
                nix-direnv.enable = true;
              };

              environment.systemPackages = with pkgs; [
                ddate
                cowsay

                postman
                dbeaver-bin
                devenv
                firefox

                ruby

                pulseaudio
                termdown
              ];

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

              environment.variables = {
                PULSE_SERVER = "tcp:localhost:4713";
              };

              system.stateVersion = "26.05";
            }
          )
        ];
      };
    };
}
