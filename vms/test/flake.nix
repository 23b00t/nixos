{
  description = "test MicroVM";

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
      index = 3;
      mac = "00:00:00:00:00:03";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.test;
        test = self.nixosConfigurations.test.config.microvm.declaredRunner;
      };
      nixosConfigurations = {
        test = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            (import ../net-config.nix { inherit lib index mac; })
            # (import ../common-config.nix {
            #   inherit lib;
            #   inherit pkgs;
            #   sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2091GSIL+SlR1BsWswg+6DZzrL+enxmXo74d/OSUwv test-vm";
            # })
            (
              { config, pkgs, ... }:
              {
                nixpkgs.config.allowUnfree = true;
                networking.hostName = "test-vm";

                microvm = {
                  registerClosure = false;

                  writableStoreOverlay = "/nix/.rw-store";
                  # hypervisor = "cloud-hypervisor";
                  hypervisor = "qemu";
                  optimize.enable = false;
                  volumes = [
                    {
                      mountPoint = "/home/user";
                      image = "home.img";
                      size = 8000;
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
                  devices = [
                    {
                      bus = "pci";
                      path = "0000:02:00.0";
                    }
                    {
                      bus = "pci";
                      path = "0000:02:00.1";
                    }
                    # Mouse
                    {
                      bus = "usb";
                      path = "vendorid=0x093a,productid=0x2533";
                    }

                    # Keyboard (Atreus)
                    {
                      bus = "usb";
                      path = "vendorid=0x1209,productid=0x2303";
                    }

                    # AX211 Bluetooth
                    {
                      bus = "usb";
                      path = "vendorid=0x8087,productid=0x0033";
                    }
                  ];
                  mem = 16384;
                  vcpu = 12;
                };

                services.qemuGuest.enable = true;

                # Back to UEFI
                boot.loader.systemd-boot.enable = true;
                boot.loader.efi.canTouchEfiVariables = true;

                # Don't use legacy GRUB in the image
                boot.loader.grub.enable = lib.mkForce false;

                services.xserver.enable = false;

                boot.kernelModules = [
                  "nvidia"
                  "nvidia_uvm"
                  "nvidia_modeset"
                  "nvidia_drm"
                ];

                hardware.graphics = {
                  enable = true;
                  enable32Bit = true;
                };

                services.xserver.videoDrivers = [ "nvidia" ];

                hardware.nvidia = {
                  modesetting.enable = true;

                  open = true;

                  package = config.boot.kernelPackages.nvidiaPackages.stable;

                  nvidiaSettings = true;
                  powerManagement.enable = false;
                  powerManagement.finegrained = false;
                };

                programs.gamescope = {
                  enable = true;
                  capSysNice = true;
                };

                programs.steam = {
                  enable = true;
                  gamescopeSession.enable = true;
                };

                services.getty.autologinUser = "user";

                # environment.sessionVariables = {
                #   WLR_NO_HARDWARE_CURSORS = "1";
                #   NIXOS_OZONE_WL = "1";
                # };
                # seatd für gamescope
                services.seatd = {
                  enable = true;
                  group = "seat";
                };

                security.wrappers.bwrap = {
                  owner = "root";
                  group = "root";
                  setuid = true;
                  source = "${pkgs.bubblewrap}/bin/bwrap";
                };

                # tty1 nicht von getty belegen lassen
                systemd.services."getty@tty1".enable = false;
                environment.loginShellInit = ''
                  if [[ "$(tty)" = "/dev/tty1" ]]; then
                    mkdir -p "$HOME/.local/state"
                    exec > >(tee -a "$HOME/.local/state/steam-autostart.log") 2>&1
                    set -x
                    exec "$HOME/gs.sh"
                  fi
                '';

                environment.etc."gs.sh" = {
                  mode = "0755";
                  text = ''
                    #!/usr/bin/env bash
                    set -xeuo pipefail

                    # Warte kurz, bis seatd Socket da ist und nutzbar
                    for i in $(seq 1 50); do
                      if [ -S /run/seatd.sock ] && [ -r /run/seatd.sock ] && [ -w /run/seatd.sock ]; then
                        break
                      fi
                      sleep 0.1
                    done

                    exec dbus-run-session -- gamescope --adaptive-sync --mangoapp --rt --steam -- steam -tenfoot
                  '';
                };

                systemd.tmpfiles.rules = [
                  "L+ /home/user/gs.sh - - - - /etc/gs.sh"
                  "L+ /home/user/.ssh/config - - - - /etc/ssh_config"
                ];
                environment.systemPackages = with pkgs; [
                  mangohud
                  pciutils
                  dbus
                  (import ../copy-between-vms.nix { inherit pkgs; })
                ];
                # D-Bus system service (sollte auf NixOS meist ohnehin an sein, aber explizit ist gut)
                services.dbus.enable = true;

                # Steam/GamepadUI erwartet NM für "active networks"
                networking.networkmanager.enable = true;

                # optional aber sinnvoll für "handheld-like" features
                services.upower.enable = true;
                time.timeZone = "Europe/Berlin";
                i18n.defaultLocale = "en_US.UTF-8";
                i18n.extraLocaleSettings = {
                  LC_TIME = "de_DE.UTF-8";
                  LC_MONETARY = "de_DE.UTF-8";
                  LC_NUMERIC = "de_DE.UTF-8";
                  LC_MEASUREMENT = "de_DE.UTF-8";
                  LC_PAPER = "de_DE.UTF-8";
                  LC_ADDRESS = "de_DE.UTF-8";
                  LC_TELEPHONE = "de_DE.UTF-8";
                  LC_NAME = "de_DE.UTF-8";
                  LC_IDENTIFICATION = "de_DE.UTF-8";
                };

                services.openssh = {
                  enable = true;
                  settings = {
                    PermitRootLogin = "no";
                    PasswordAuthentication = false;
                  };
                };
                security.sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };
                users.groups.users = { };
                users.groups.seat = { };

                users.users.user = {
                  isNormalUser = true;
                  group = "users";
                  extraGroups = [
                    "wheel"
                    "seat"
                    "video"
                    "render"
                    "input"
                  ];
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2091GSIL+SlR1BsWswg+6DZzrL+enxmXo74d/OSUwv test-vm"
                  ];
                };

                environment.etc."ssh_config".text = ''
                  Host *
                      StrictHostKeyChecking no
                      UserKnownHostsFile /dev/null
                  Host 10.0.0.254 
                      IdentitiesOnly yes
                '';

                system.stateVersion = "25.05";
              }
            )
          ];
        };
      };
    };
}
