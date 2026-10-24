# Hardware of the machines for NoX (nox.lib.mkSystems, NoX
# nixos/registry/machine.nix): USB inventory, passed-through PCI devices and
# the host profile per machine, plus the backup volumes. The domains are in
# vms/vms.nix.
{ lib }:
let
  # Central USB/Bluetooth inventory and ownership policy, per machine.
  # Owner `host` = input device forwarded to dom0 by the input proxy; another
  # VM as owner = exported via USB/IP; owner `sys-usb` = stays there.
  usbDevicesFor = {
    hp = [
      {
        name = "keyboard-atreus";
        vendorId = "1209";
        productId = "2303";
        policy = "host-allow";
        defaultOwner = "host";
        allowedOwners = [
          "host"
          "steam"
        ];
        microvmUsbPath = "vendorid=0x1209,productid=0x2303";
      }
      {
        name = "mouse-main";
        vendorId = "260d";
        productId = "1121";
        policy = "host-allow";
        defaultOwner = "host";
        allowedOwners = [
          "host"
          "steam"
        ];
        microvmUsbPath = "vendorid=0x260d,productid=0x1121";
      }
      {
        name = "mouse-mobile";
        vendorId = "046a";
        productId = "c092";
        policy = "host-allow";
        defaultOwner = "host";
        allowedOwners = [
          "host"
          "steam"
        ];
        microvmUsbPath = "vendorid=0x046a,productid=0xc092";
      }
      # hp (Xen, v2.6): both xHCI controllers belong to sys-usb.
      {
        name = "webcam-hp";
        vendorId = "0408";
        productId = "5365";
        policy = "vm-reserved";
        defaultOwner = "chat";
        allowedOwners = [ "chat" ];
        microvmUsbPath = "vendorid=0x0408,productid=0x5365";
      }
      {
        name = "bluetooth-hp";
        vendorId = "0bda";
        productId = "b00e";
        policy = "vm-reserved";
        defaultOwner = "sys-usb";
        # vm-usb attach copies sys-usb's pairings along (vms/usb-links.nix)
        bluetooth = true;
        allowedOwners = [
          "sys-usb"
          "chat"
          "disp"
        ];
        microvmUsbPath = "vendorid=0x0bda,productid=0xb00e";
      }
      {
        name = "fingerprint-hp";
        vendorId = "04f3";
        productId = "0c00";
        policy = "vm-reserved";
        defaultOwner = "sys-usb";
        allowedOwners = [ "sys-usb" ];
        microvmUsbPath = "vendorid=0x04f3,productid=0x0c00";
      }
      {
        # External test mouse for the input proxy
        name = "mouse-sharkforce";
        vendorId = "093a";
        productId = "2533";
        policy = "host-allow";
        defaultOwner = "host";
        allowedOwners = [ "host" ];
        microvmUsbPath = "vendorid=0x093a,productid=0x2533";
      }
    ];

    # xmg (Xen): the only xHCI controller (00:14.0) belongs to sys-usb, USB
    # keyboard and mice come back to dom0 over the input proxy. The internal
    # keyboard (i8042) and touchpad (I2C) are not on USB and stay in dom0.
    xmg = [
      {
        name = "keyboard-atreus";
        vendorId = "1209";
        productId = "2303";
        policy = "host-allow";
        defaultOwner = "host";
        allowedOwners = [
          "host"
          "steam"
        ];
        microvmUsbPath = "vendorid=0x1209,productid=0x2303";
      }
      {
        name = "mouse-main";
        vendorId = "260d";
        productId = "1121";
        policy = "host-allow";
        defaultOwner = "host";
        allowedOwners = [
          "host"
          "steam"
        ];
        microvmUsbPath = "vendorid=0x260d,productid=0x1121";
      }
      {
        name = "mouse-mobile";
        vendorId = "046a";
        productId = "c092";
        policy = "host-allow";
        defaultOwner = "host";
        allowedOwners = [
          "host"
          "steam"
        ];
        microvmUsbPath = "vendorid=0x046a,productid=0xc092";
      }
      {
        name = "bluetooth-ax211";
        vendorId = "8087";
        productId = "0033";
        policy = "vm-reserved";
        defaultOwner = "sys-usb";
        # vm-usb attach copies sys-usb's pairings along (vms/usb-links.nix)
        bluetooth = true;
        allowedOwners = [
          "sys-usb"
          "steam"
          "disp"
        ];
        microvmUsbPath = "vendorid=0x8087,productid=0x0033";
      }
      {
        name = "webcam-main";
        vendorId = "2b7e";
        productId = "c906";
        policy = "vm-reserved";
        defaultOwner = "chat";
        allowedOwners = [ "chat" ];
        microvmUsbPath = "vendorid=0x2b7e,productid=0xc906";
      }
      {
        # Keyboard backlight controller (internal, on USB)
        name = "ite-8291";
        vendorId = "048d";
        productId = "600b";
        policy = "vm-reserved";
        defaultOwner = "sys-usb";
        allowedOwners = [ "sys-usb" ];
        microvmUsbPath = "vendorid=0x048d,productid=0x600b";
      }
      {
        name = "verbatim usb-stick";
        vendorId = "18a5";
        productId = "0243";
        policy = "vm-reserved";
        defaultOwner = "sys-usb";
        allowedOwners = [ "sys-usb" ];
        microvmUsbPath = "vendorid=0x18a5,productid=0x0243";
      }
    ];
  };

  # Xen: passed-through devices go to pciback (`xl pci-assignable-add` when the
  # VM starts), not vfio-pci, so they don't belong in the vfio ids
  pciDeviceIdsFor = {
    hp = {
      nic = [ ];
    };
    xmg = {
      nic = [ ];
    };
  };

  pciDevicePathsFor = {
    hp = {
      nic = [
        "0000:01:00.0" # RTL8821CE WLAN (10ec:c821) -> sys-net
      ];
      usb = [
        "0000:03:00.3" # xHCI (1022:1639): webcam, Bluetooth -> sys-usb
        "0000:03:00.4" # xHCI (1022:1639): fingerprint, external ports -> sys-usb
      ];
    };
    xmg = {
      # The CNVi WLAN is a function of the same device as the xHCI in sys-usb.
      # With MSI (PV dom0) they no longer share an INTx, and 00:14.3 has its
      # own FLR, so it goes to sys-net on its own (as in Qubes, 2026-10-14)
      nic = [
        "0000:05:00.0" # RTL8125 Ethernet (10ec:8125) -> sys-net
        "0000:00:14.3" # CNVi WLAN (8086:7a70, iwlwifi) -> sys-net
      ];
      usb = [
        "0000:00:14.0" # xHCI (8086:7a60): all USB devices -> sys-usb
      ];
      # NVIDIA RTX 5060 (10de:2d19) + audio (10de:22eb) -> steam (v4)
      gpu = [
        "0000:02:00.0"
        "0000:02:00.1"
      ];
    };
  };

  hostProfiles = {
    hp = {
      cpuVendor = "amd";
      # PV dom0 like the xmg, so the test machine matches it (2026-10-12)
      dom0Pv = true;
      blockedHostDrivers = {
        nic = [ ];
        # dom0 never drives the WLAN card; sys-net owns it
        wifi = [ "rtw88_8821ce" ];
      };
      # Test phase (v2.5): dom0 reaches the internet through sys-net (HTTPS/DNS/
      # NTP only) and is reachable by SSH from this LAN via a port forward in
      # sys-net. null = dom0 fully offline.
      dom0TestAccess = {
        lan = "192.168.178.0/24";
      };
    };
    xmg = {
      cpuVendor = "intel";
      # PV dom0 (as Qubes): under PVH the passed-through RTL8125 (INTx only)
      # uploaded at ~50 KB/s (hp over WLAN: 4.4 MB/s), stalling Tor and the
      # builder, and a stopped sys-net could not be destroyed (2026-10-11)
      dom0Pv = true;
      # Blacklists nouveau/nvidia in dom0, the dGPU stays unbound for steam
      dGpuVendor = "nvidia";
      blockedHostDrivers = {
        # dom0 never drives the NICs; sys-net owns them
        nic = [ "r8169" ];
        wifi = [ "iwlwifi" ];
      };
      # dom0 offline: updates only via the builder (dom0-update)
      dom0TestAccess = null;
    };
  };

  # LUKS volumes `nox backup` may open (cryptsetup luksUUID), any number of
  # backup disks. Only a listed volume is ever opened, so a disk may carry
  # other LUKS volumes. Empty: the only LUKS volume on the attached disk
  # (several: error listing them)
  backupLuksUuids = [
    # Samsung T7 Touch, sda1 (309.8 GB); sda2 holds other data and is never opened
    "c1b23529-a163-42c0-8aa4-9b4357c44b8c"
  ];
in
{
  machines = lib.mapAttrs (host: profile: {
    inherit profile;
    usbDevices = usbDevicesFor.${host};
    pciDeviceIds = pciDeviceIdsFor.${host};
    pciDevicePaths = pciDevicePathsFor.${host};
  }) hostProfiles;
  inherit backupLuksUuids;
}
