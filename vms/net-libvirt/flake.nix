{
  description = "Libvirt NixOS VM for isolated apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      graphic-net = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          ({ config, pkgs, ... }: {
            networking.hostName = "graphic-net";
            services.xserver.enable = true;
            services.xserver.displayManager.autoLogin.enable = true;
            services.xserver.displayManager.autoLogin.user = "user";
            services.xserver.desktopManager.gnome.enable = true;

            users.users.user = {
              isNormalUser = true;
              password = "trash";
              extraGroups = [ "wheel" "networkmanager" ];
            };

            environment.systemPackages = with pkgs; [
              firefox
              discord
              zoom-us
              telegram-desktop
            ];

            system.stateVersion = "24.05";
          })
        ];
      };
    };

    packages.x86_64-linux = {
      qemuImage = self.nixosConfigurations.graphic-net.config.system.build.qemuImage;
      default = self.packages.x86_64-linux.qemuImage;
    };
  };
}
