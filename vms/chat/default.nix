{ lib, pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/wprs.nix
    ../modules/yazi-config.nix
  ];

  services.net-config = {
    enable = true;
    index = 2;
    mac = "00:00:00:00:00:02";
  };

  services.common-config = {
    enable = true;
  };

  nixpkgs.config.allowUnfree = true;
  networking.hostName = "chat-vm";

  users.users.user.extraGroups = lib.mkAfter [ "video" ];

  # Webcam: USB/IP from sys-usb (vms/modules/usbip-client.nix, registry owner)
  microvm = {
    hypervisor = "xen";

    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 4096;
      }
    ];
    # Boots with 4096 MB, the RAM balancer grows it up to 8192 MB
    mem = 8192;
    balloon = true;
    initialBalloonMem = 4096;
    vcpu = 2;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  services.gnome.gnome-keyring.enable = true;

  environment.systemPackages = with pkgs; [
    (pkgs.symlinkJoin {
      name = "vesktop";
      paths = [ pkgs.vesktop ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/vesktop" --add-flags "--disable-gpu"
      '';
    })
    telegram-desktop
    slack
    element-desktop
    google-chrome
    chromium

    mesa
    vulkan-loader
    feishin
    nuclear
    ffmpeg
    yt-dlp

    kitty
    v4l-utils
  ];

  system.stateVersion = "26.05";
}
