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
    ./xen.nix # Xen dom0 instead of KVM

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

  networking.hostName = lib.mkForce "xmg";
}
