{
  description = "Steam VM (UEFI qcow2 for libvirt)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # qcow2 builder, avoids make-disk-image/cptofs/LKL
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      steamModule =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          networking.hostName = "steam-vm";
          time.timeZone = "UTC";
          system.stateVersion = "24.05";

          services.qemuGuest.enable = true;

          # Back to UEFI
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = false;

          # Don't use legacy GRUB in the image
          boot.loader.grub.enable = lib.mkForce false;

          services.xserver.enable = false;

          boot.kernelParams = [ "nvidia-drm.modeset=1" ];
          boot.blacklistedKernelModules = [ "nouveau" ];

          hardware.graphics = {
            enable = true;
            enable32Bit = true;
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

          # Root filesystem (image root disk)
          fileSystems."/" = {
            device = "/dev/disk/by-label/nixos";
            fsType = "ext4";
          };

          # EFI System Partition
          fileSystems."/boot" = {
            device = "/dev/disk/by-label/ESP";
            fsType = "vfat";
          };

          swapDevices = [ ];

          # Persistent Steam data disk
          fileSystems."/mnt/steam" = {
            device = "/dev/disk/by-label/STEAMDATA";
            fsType = "ext4";
            options = [
              "nofail"
              "x-systemd.device-timeout=1"
            ];
          };

          environment.systemPackages = with pkgs; [ mangohud ];

          services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
          };

          users.users.user = {
            isNormalUser = true;
            extraGroups = [
              "wheel"
              "video"
              "input"
              "audio"
            ];
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
        };

      steamSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ steamModule ];
      };

      # Build qcow2 via nixos-generators (no cptofs/LKL)
      steamOsQcow2 = nixos-generators.nixosGenerate {
        inherit system;
        pkgs = pkgs;

        modules = [ steamModule ];

        format = "qcow";

        # optional: label expectations; nixos-generators generally labels root "nixos"
        # and ESP "ESP" on UEFI images. If labels differ, we can adapt fileSystems.
      };
      steamOsQcow2Named = pkgs.runCommand "steam-os-qcow2" { } ''
        set -euo pipefail
        mkdir -p $out
        # nixos-generators output kann je nach version nixos.qcow2 heißen
        cp -v ${steamOsQcow2}/nixos.qcow2 $out/steam-os.qcow2
      '';

      steamDeployScript = pkgs.writeShellScript "deploy-steam-vm-image" ''
        set -euo pipefail

        src="${steamOsQcow2Named}/steam-os.qcow2"
        dst_dir="/var/lib/libvirt/images"
        dst="$dst_dir/steam-os.qcow2"

        install -d -m 0755 "$dst_dir"
        # atomar ersetzen
        install -m 0644 "$src" "$dst"

        # optional: ownership an libvirt-qemu, wenn vorhanden (NixOS variiert)
        if id -u libvirt-qemu >/dev/null 2>&1; then
          chown libvirt-qemu:kvm "$dst" || true
        fi

        echo "Deployed $dst from $src"
      '';
    in
    {
      nixosConfigurations.steam-vm = steamSystem;

      packages.${system} = {
        steam-os-qcow2 = steamOsQcow2Named;
        steam-os-deploy = steamDeployScript;
        default = steamOsQcow2Named;
      };
    };
}
