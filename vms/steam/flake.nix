{
  description = "Steam VM (UEFI qcow2 for libvirt)";

  # folgt deinem repo: nixos-unstable
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

      steamModule = { config, pkgs, lib, ... }: {
        nixpkgs.config.allowUnfree = true;

        networking.hostName = "steam-vm";
        time.timeZone = "UTC";
        system.stateVersion = "24.05";

        # libvirt guest integration
        services.qemuGuest.enable = true;

        # UEFI boot
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = false;

        services.xserver.enable = false;

        boot.kernelParams = [ "nvidia-drm.modeset=1" ];
        boot.blacklistedKernelModules = [ "nouveau" ];

        hardware.opengl = {
          enable = true;
          driSupport32Bit = true;
        };

        hardware.nvidia = {
          modesetting.enable = true;
          open = false;
          nvidiaSettings = false;
        };

        programs.gamescope = {
          enable = true;
          capSysNice = true;
        };
        programs.steam = {
          enable = true;
          gamescopeSession.enable = true;
        };

        environment.systemPackages = with pkgs; [
          mangohud
        ];

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          pulse.enable = true;
        };

        users.users.user = {
          isNormalUser = true;
          extraGroups = [ "wheel" "video" "input" "audio" ];
          initialPassword = "user";
        };
        services.getty.autologinUser = "user";

        environment.sessionVariables = {
          WLR_NO_HARDWARE_CURSORS = "1";
          NIXOS_OZONE_WL = "1";
        };

        environment.loginShellInit = ''
          if [[ "$(tty)" = "/dev/tty1" ]]; then
            set -xeuo pipefail

            gamescopeArgs=( --adaptive-sync --hdr-enabled --mangoapp --rt --steam )
            steamArgs=( -pipewire-dmabuf -tenfoot )
            mangoConfig=( cpu_temp gpu_temp ram vram )

            export MANGOHUD=1
            export MANGOHUD_CONFIG="$(IFS=,; echo "''${mangoConfig[*]}")"
            exec gamescope "''${gamescopeArgs[@]}" -- steam "''${steamArgs[@]}"
          fi
        '';

        # Persistente Steam library via 2. Disk (label STEAMDATA)
        fileSystems."/mnt/steam" = {
          device = "/dev/disk/by-label/STEAMDATA";
          fsType = "ext4";
          options = [ "nofail" "x-systemd.device-timeout=1" ];
        };
      };

      steamSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ steamModule ];
      };

      makeDiskImage = import (nixpkgs + "/nixos/lib/make-disk-image.nix");
    in
    {
      nixosConfigurations.steam-vm = steamSystem;

      packages.${system}.steam-os-qcow2 = makeDiskImage {
        inherit pkgs;
        lib = pkgs.lib;

        config = steamSystem.config;

        format = "qcow2";
        diskSize = 40 * 1024; # MiB => 40GiB OS disk
      };

      packages.${system}.default = self.packages.${system}.steam-os-qcow2;
    };
}
