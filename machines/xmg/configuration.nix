{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  boot = {
    initrd = {
      luks.devices."luks-90b3e0c2-5fdb-48ac-b4b9-3ee6f5cb533e".device =
        "/dev/disk/by-uuid/90b3e0c2-5fdb-48ac-b4b9-3ee6f5cb533e";
    };
  };

  imports = [
    ./hardware-configuration.nix # Auto-generated hardware config
    ./xen.nix # Xen dom0 instead of KVM

    # CPU Configuration (choose one):
    inputs.nixos-hardware.nixosModules.common-cpu-intel # Intel CPUs
  ];

  # Keyboard layout
  console.keyMap = "us";
  services = {
    xserver.xkb = {
      layout = "us";
      variant = "intl";
      options = "grp:alt_shift_toggle";
    };

    keyd = {
      enable = true;
      keyboards = {
        internal = {
          # IDs, wie z.B. ["0001:0001"] (Vendor:Product)
          # journalctl -xeu keyd.service | grep -i keyboard
          ids = [ "0001:0001" ];
          settings = {
            main = {
              y = "z";
              z = "y";
              # leftctrl = "esc";
              # esc = "leftctrl";
            };
          };
        };
      };
    };

    # sddm greeter (weston) on the internal panel at 60 Hz. Weston takes the
    # preferred 300 Hz, niri inherits that state at login and cannot light the
    # third output (atomic test EINVAL, 2026-10-15). Same as the nixpkgs weston
    # command plus an [output] section.
    displayManager.sddm.wayland.compositorCommand =
      let
        xkb = config.services.xserver.xkb;
        westonIni = (pkgs.formats.ini { }).generate "weston.ini" {
          libinput = {
            enable-tap = config.services.libinput.mouse.tapping;
            left-handed = config.services.libinput.mouse.leftHanded;
          };
          keyboard = {
            keymap_model = xkb.model;
            keymap_layout = xkb.layout;
            keymap_variant = xkb.variant;
            keymap_options = xkb.options;
          };
          output = {
            name = "eDP-1";
            mode = "2560x1600@60";
          };
        };
      in
      "${lib.getExe pkgs.weston} --shell=kiosk -c ${westonIni}";
  };

  networking.hostName = lib.mkForce "xmg";
}
