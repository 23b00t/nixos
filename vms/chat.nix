# chat: messengers (apps in vms.nix), music, the webcam over USB/IP from
# sys-usb (registry owner); audio over pipewire into dom0's pulse.
{ lib, pkgs, ... }:
{
  services = {
    common-config.browser = "chromium-browser.desktop";
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    gnome.gnome-keyring.enable = true;
  };

  users.users.user.extraGroups = lib.mkAfter [ "video" ];

  security.rtkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  environment.systemPackages = with pkgs; [
    # vesktop without GPU (apps.vesktop.install = false)
    (pkgs.symlinkJoin {
      name = "vesktop";
      paths = [ pkgs.vesktop ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/vesktop" --add-flags "--disable-gpu"
      '';
    })
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
}
