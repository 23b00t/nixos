{
  description = "Steam VM (qcow2)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.steam-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # qcow2-Target bereitstellen
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
              # optionale Defaults (frei anpassbar, virt-manager setzt zur Laufzeit anderes):
              virtualisation.qemu.memorySize = 16000;
              virtualisation.qemu.cores = 8;
              virtualisation.qemu.diskInterface = "virtio";
            }
          )

          # Hauptkonfiguration
          (
            { config, pkgs, ... }:
            {
              nixpkgs.config.allowUnfree = true;

              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;

              boot.kernelParams = [ "nvidia-drm.modeset=1" ];
              boot.blacklistedKernelModules = [ "nouveau" ];

              services.xserver.enable = false; # Wayland-only via Gamescope

              hardware.opengl = {
                enable = true;
                driSupport32Bit = true;
              };

              hardware.nvidia = {
                modesetting.enable = true;
                open = false;
                nvidiaSettings = false;
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

              environment.systemPackages = with pkgs; [
                mangohud
              ];

              services.pipewire = {
                enable = true;
                alsa.enable = true;
                pulse.enable = true;
              };

              hardware.bluetooth.enable = true;
              services.blueman.enable = true;

              environment.sessionVariables = {
                WLR_NO_HARDWARE_CURSORS = "1";
                NIXOS_OZONE_WL = "1";
              };

              services.getty.autologinUser = "user";

              users.users.user = {
                isNormalUser = true;
                extraGroups = [
                  "wheel"
                  "video"
                  "input"
                  "audio"
                ];
                openssh.authorizedKeys.keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/v5mOcbtZ/shL0s5Y2xJYkfEdkPMsznhEC3X7cGgmL steam-vm";
              };

              services.openssh = {
                enable = true;
                settings = {
                  PermitRootLogin = "no";
                  PasswordAuthentication = false;
                  MaxSessions = 100;
                  MaxStartups = "30:50:100";
                  LoginGraceTime = 30;
                };
                extraConfig = ''
                  # TCP Keepalive für stabile Verbindungen
                  TCPKeepAlive yes
                  ClientAliveInterval 60
                  ClientAliveCountMax 3
                  # Login-Beschleunigung
                  UseDNS no
                '';
              };

              environment.loginShellInit = ''
                if [[ "$(tty)" = "/dev/tty1" ]]; then
                  set -xeuo pipefail

                  gamescopeArgs=(
                    --adaptive-sync
                    --hdr-enabled
                    --mangoapp
                    --rt
                    --steam
                  )
                  steamArgs=(
                    -pipewire-dmabuf
                    -tenfoot
                  )
                  mangoConfig=(
                    cpu_temp
                    gpu_temp
                    ram
                    vram
                  )

                  export MANGOHUD=1
                  export MANGOHUD_CONFIG="$(IFS=,; echo "''${mangoConfig[*]}")"
                  exec gamescope "''${gamescopeArgs[@]}" -- steam "''${steamArgs[@]}"
                fi
              '';

              networking.hostName = "steam-vm";
              time.timeZone = "UTC";
              system.stateVersion = "24.05";
            }
          )
        ];
      };
    };
}
