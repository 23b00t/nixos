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
            (
              { config, pkgs, ... }:
              let
                defaultPkgs = import ../default-pkgs.nix { inherit pkgs; };
                devenvConfig = import ./devenv.nix {
                  inherit pkgs config;
                };

                envVars = devenvConfig.env or { };
                devPackages = devenvConfig.packages or [ ];
              in
              {
                networking.hostName = "php-vm";
                services.ide.enable = true;
                services.zsh-env.enable = true;

                microvm = {
                  registerClosure = false;
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 12000;
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
                # 1. Pakete aus devenv in die Systempakete der VM einbauen
                environment.systemPackages = (config.environment.systemPackages or [ ]) ++ devPackages;

                # 2. env.* von devenv in NixOS environment.variables spiegeln
                environment.variables = lib.mkMerge [
                  (config.environment.variables or { })
                  envVars
                ];

                # 3. „enterShell“ als Login‑Message o.ä. verwenden (optional)
                programs.bash.loginShellInit = lib.mkAfter ''
                  # Hinweis aus devenv enterShell beim Login anzeigen
                  cat <<'EOF'
                  ${devenvConfig.enterShell or ""}
                  EOF
                '';

                # 4. Scripts.* aus devenv als ausführbare Wrapper zur Verfügung stellen (optional)
                environment.systemPackages = [
                  (pkgs.writeShellScriptBin "install-composer-deps" (
                    devenvConfig.scripts.install-composer-deps.exec or ""
                  ))
                  (pkgs.writeShellScriptBin "install-captainhook" (
                    devenvConfig.scripts.install-captainhook.exec or ""
                  ))
                  (pkgs.writeShellScriptBin "install-phpcs" (devenvConfig.scripts.install-phpcs.exec or ""))
                  (pkgs.writeShellScriptBin "setup-php-fpm" (devenvConfig.scripts.setup-php-fpm.exec or ""))
                ]
                ++ (config.environment.systemPackages or [ ])
                ++ devPackages;

                # 5. processes.* als systemd‑Services abbilden (Beispiel für php-fpm)
                systemd.services."devenv-php-fpm" = {
                  description = "PHP-FPM from devenv processes.php-fpm";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "network.target" ];
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = devenvConfig.processes.php-fpm.exec;
                    Restart = "on-failure";
                    WorkingDirectory = "/srv/app"; # oder DEVENV_ROOT/Projektverzeichnis
                  };
                };

                # 6. Nginx/MySQL lieber direkt als NixOS-Services konfigurieren
                #    (du hast in der devenv.nix ja schon fast NixOS-Optionen; die kannst du 1:1 übernehmen)
                services.mysql = devenvConfig.services.mysql // {
                  enable = true;
                };
                services.nginx = devenvConfig.services.nginx // {
                  enable = true;
                };

                # 7. devenv als Tool trotzdem installieren, damit du in der VM weiter `devenv up` etc. machen kannst
                environment.systemPackages = (config.environment.systemPackages or [ ]) ++ [ pkgs.devenv ];
                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
