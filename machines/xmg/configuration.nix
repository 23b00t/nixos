{
  lib,
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

    # CPU Configuration (choose one):
    inputs.nixos-hardware.nixosModules.common-cpu-intel # Intel CPUs
  ];

  # Keyboard layout
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "intl";
  services.xserver.xkb.options = "grp:alt_shift_toggle";

  services.keyd = {
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

  services.usbguard = {
    enable = true;
    rules = ''
      allow id 05e3:0610 name "USB2.1 Hub" with-interface { 09:00:01 09:00:02 }
      allow id 1a40:0801 name "USB 2.0 Hub" with-interface 09:00:00
      allow id 05e3:0620 name "USB3.2 Hub" with-interface 09:00:00

      allow id 093a:2533 name "SHARKFORCE OpticalMouse" with-interface { 03:01:02 03:00:01 }
      allow id 1209:2303 serial "CDatreus" name "Atreus" with-interface { 02:02:00 0a:00:00 03:01:01 03:00:00 03:00:00 }

      allow id 2b7e:c906 serial "200901010001" name "FHD WebCam" with-interface { 0e:01:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:01:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 fe:01:01 }
      allow id 8087:0033 with-interface { e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 }
    '';
  };
  # Steam VM CPU pinning
  systemd.services."microvm@steam".serviceConfig.CPUAffinity = "0 1 2 3 4 5 6 7 8 9";

  networking.hostName = lib.mkForce "xmg";
}
