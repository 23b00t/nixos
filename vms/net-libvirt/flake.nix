{
  description = "Libvirt NixOS VM for isolated apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.graphic-net = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ config, pkgs, ... }: {
          imports = [ ];

          virtualisation.libvirtd.enable = true;

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
}
