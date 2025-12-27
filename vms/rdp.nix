{ lib, ... }:
{
  # Setup xrdp with fluxbox
  networking.firewall = {
    allowedTCPPorts = [ 3389 ];
    allowedUDPPorts = [ 3389 ];
  };
  services = {
    xrdp = {
      enable = true;
      audio.enable = true;
    };
    xserver.enable = true;
    xserver.windowManager.fluxbox.enable = true;
    pipewire.enable = false;
    pulseaudio.enable = true;
  };

  users.users.user = {
    password = "trash";
    extraGroups = lib.mkAfter [ "video" ];
  };

  # NOTE: Hyprland experiment (no success yet, no rdp server running)
  # grdctl --headless needs to be setup completly
  # programs.hyprland.enable = true;
  # services.greetd.enable = true;
  # services.greetd.settings.default_session = {
  #   command = "${pkgs.hyprland}/bin/Hyprland";
  #   user = "user";
  # };
  # services.gnome.gnome-remote-desktop.enable = true;
  # systemd.services.gnome-remote-desktop = {
  #   wantedBy = [ "graphical.target" ];
  # };
  # services.gnome.gnome-keyring.enable = true;
  # services.dbus.enable = true;

  # NOTE: Working Xfce4 + xrdp setup
  # services.xrdp.enable = true;
  # services.xrdp.defaultWindowManager = "xfce4-session";
  # services.xserver.enable = true;
  # services.xserver.displayManager.lightdm.enable = true;
  # services.xserver.desktopManager.xfce.enable = true;
}
