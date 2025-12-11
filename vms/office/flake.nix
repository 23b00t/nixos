{
  description = "Office MicroVM";

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
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      index = 3;
      mac = "00:00:00:00:00:03";
    in
    {
      nixpkgs.pkgs = pkgs;
      packages.${system} = {
        default = self.packages.${system}.office;
        chat = self.nixosConfigurations.office.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        office = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "office-vm";

                users.groups.user = { };
                users.users.user = {
                  password = "trash";
                  isNormalUser = true;
                  group = "user";
                  extraGroups = [ "wheel" ];
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC76Fb5xSeNdZ9BVPf7OdLWhULXgb1OCAgPfYoeLZBl office-vm"
                  ];
                  linger = true;
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = false;
                  };
                };
                microvm = {
                  registerClosure = false;
                  # vsock.cid = 3;
                  writableStoreOverlay = "/nix/.rw-store";
                  hypervisor = "cloud-hypervisor";
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 1028;
                    }
                    {
                      image = "nix-store-overlay.img";
                      mountPoint = config.microvm.writableStoreOverlay;
                      size = 2048;
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
                  mem = 6144;
                  vcpu = 2;
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

                # Audio setup for termusic over PipeWire
                services.pulseaudio.enable = false;
                services.pipewire = {
                  enable = true;
                  pulse.enable = true;
                  alsa.enable = true;
                  alsa.support32Bit = true;
                  jack.enable = true;
                };
                environment.sessionVariables = {
                  PULSE_SERVER = "tcp:localhost:4713";
                };

                environment.systemPackages = with pkgs; [
                  termusic
                  yt-dlp
                  onlyoffice-desktopeditors
                  gimp
                  inkscape
                  vlc
                  pinta
                  pdfarranger
                  wprs
                  xwayland
                ];

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
