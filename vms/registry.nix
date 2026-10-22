let
  # Central VM registry used across host, home-manager scripts and helper tools.
  # Each VM entry has the following fields:
  #   name        : long name without "-vm" suffix (e.g. "nvim")
  #   short       : short alias used in CLI tools (e.g. "n")
  #   ip          : IPv4 address on the 10.0.0.0/24 network
  #   autostart   : whether the VM should autostart via microvm.host
  #   restartIfChanged: whether the VM should be automatically restarted if its configuration changes; defaults to true
  #   nat         : whether the VM should be included in networking.nat.internalIPs
  #   allowGitHubAgent : whether the VM should receive the dedicated forwarded GitHub SSH agent/socket
  #   enableHostDbusForward : whether host should keep persistent forwarded /tmp/ssh_dbus.sock for this VM (defaults to true)
  #   extraSSH    : extra SSH matchOptions for home.ssh (may be [])
  #   hostSSHKey  : public key dom0 logs in with over SSH; only the builder (dom0-update), every other
  #                 domain has no sshd (xen-migration.md SSH removal, dom0 uses nox-rpc)
  #   features    : arbitrary list of features/tags used for dynamic grouping in helper tools
  #   storeGroup  : shared read-only store image (vms/store-groups.nix): "sys" | "dev" | "desktop" | "prop"; absent = own image
  #   memPriority : RAM balancer priority when host RAM is short (modules/xen-memory.nix); higher grows first, default 0
  #   hosts       : machines that run this VM (`forHost` below); absent = all machines, [ ] = none (definition kept)
  #   clipboard   : explicit copy/paste through dom0 (vm-clip, Mod+Alt+C/V): "allow" | "ask" (copying out of
  #                 the VM asks in dom0) | "deny"; absent = "deny" for sys-* VMs, else "allow"
  #   uplink      : driver domain serving the VM's uplink (needs `nat`): "sys-firewall" (default) | "sys-vpn" | "sys-net"
  #                 (sys-firewall and sys-print only; vms/modules/net-config.nix)
  #   backup      : /home in the quick backup (vm-backup, W1); absent = true except sys-* and disposables
  #   egress      : outgoing traffic the VM may send through sys-firewall: [ { to = "<cidr>"; ports = [ <port> … ]; } … ]
  #                 (no ports = all ports to that net); absent = everything. DNS always via sys-firewall's resolver
  #   label       : trust label (Qubes-like), the window border color in dom0 (home/desktop/theme.nix
  #                 `labels`, niri rules on the "[<vm>] " app id prefix from wprsc): "sys" | "dev" | "personal" |
  #                 "untrusted" | "vault" | "anon"; absent = "untrusted"
  #   copy        : files between domains over nox-rpc (vm-copy in a VM, nox copy in dom0): { incoming; outgoing; },
  #                 each "ask" | "warn" (ask, the user types the VM's name) | "deny"; absent: sys-* incoming "ask",
  #                 outgoing "deny", else "ask"; dom0 -> VM needs no answer except for "warn"; never VM -> dom0
  #   disposable  : boots empty every time: dom0 deletes the VM's home and store overlay images before start
  #                 and after stop (machines/xen-dom0.nix); other volumes are data volumes and stay;
  #                 `manage-vms restart --fresh <vm>` (nox restart --fresh) also sets those aside
  #   labTarget   : kali may test this VM's apps: `vm-lab attach <vm>` hangs a vif on sys-firewall's vm-lab (10.5.0.<last octet>, vms/modules/lab-target.nix)
  vms = [
    {
      name = "nvim";
      short = "n";
      label = "dev";
      storeGroup = "dev";
      ip = "10.0.0.1";
      autostart = true;
      nat = true;
      allowGitHubAgent = true;
      features = [ "yazi" ];
    }
    {
      name = "chat";
      short = "c";
      label = "personal";
      storeGroup = "prop";
      ip = "10.0.0.2";
      autostart = true;
      nat = true;
      features = [ "yazi" ];
    }
    # {
    #   name = "test";
    #   short = "t";
    #   storeGroup = "dev";
    #   ip = "10.0.0.3";
    #   autostart = false;
    #   nat = true;
    # }
    {
      name = "net";
      short = "net";
      label = "untrusted";
      storeGroup = "desktop";
      ip = "10.0.0.5";
      autostart = true;
      nat = true;
      features = [ "yazi" ];
    }
    {
      name = "coding";
      short = "cc";
      label = "dev";
      ip = "10.0.0.6";
      autostart = true;
      nat = true;
      allowGitHubAgent = true;
      enableHostDbusForward = true;
      features = [ "yazi" ];
      # kali tests its apps over the lab bridge (vm-lab attach)
      labTarget = true;
    }
    {
      # Windows apps (Bottles, no gaming); internet, but no session bus and
      # no GitHub agent
      name = "win";
      short = "w";
      label = "untrusted";
      storeGroup = "prop";
      ip = "10.0.0.7";
      autostart = false;
      nat = true;
      allowGitHubAgent = false;
      enableHostDbusForward = false;
    }
    {
      name = "office";
      short = "o";
      label = "personal";
      storeGroup = "desktop";
      ip = "10.0.0.9";
      autostart = false;
      nat = false;
      features = [ "yazi" ];
    }
    {
      name = "vault";
      short = "v";
      label = "vault";
      storeGroup = "desktop";
      ip = "10.0.0.10";
      autostart = false;
      nat = false;
      clipboard = "ask";
      copy.incoming = "warn";
      features = [ "yazi" ];
    }
    {
      name = "irc";
      short = "i";
      label = "personal";
      storeGroup = "desktop";
      ip = "10.0.0.11";
      autostart = true;
      nat = false;
    }
    {
      name = "sys-usb";
      short = "su";
      label = "sys";
      storeGroup = "sys";
      ip = "10.0.0.23";
      autostart = false;
      nat = false;
      disposable = true;
      features = [ "yazi" ];
    }
    {
      name = "sys-net";
      short = "sn";
      label = "sys";
      storeGroup = "sys";
      ip = "10.0.0.253";
      autostart = true;
      nat = false;
      disposable = true;
    }
    {
      name = "builder";
      short = "b";
      label = "sys";
      ip = "10.0.0.25";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINX+ZshJR9vhy9Fq1J6VteXQASQhNEzFtQ1bV1L+j1eY builder-vm";
      allowGitHubAgent = false;
      enableHostDbusForward = false;
      memPriority = 10;
      # nothing in or out by nox-rpc copy (the build VM sees untrusted code)
      copy = {
        incoming = "deny";
        outgoing = "deny";
      };
    }
    {
      # Print driver domain (C2): CUPS with driverless queues, PDFs come in
      # over RPC (`vm-print`), network only to LAN printers (sys-net)
      name = "sys-print";
      short = "sp";
      label = "sys";
      storeGroup = "sys";
      ip = "10.0.0.26";
      autostart = false;
      nat = true;
      # Prints into the local network: its rule lives in sys-net (IPP to the LAN)
      uplink = "sys-net";
      # holds no user data: print jobs only
      copy = {
        incoming = "deny";
        outgoing = "deny";
      };
      allowGitHubAgent = false;
      enableHostDbusForward = false;
    }
    {
      # Xen HVM with the dGPU (PCI passthrough); input and Bluetooth via
      # USB/IP from sys-usb (`vm-usb attach <device> steam`)
      name = "steam";
      short = "s";
      label = "untrusted";
      ip = "10.0.0.12";
      autostart = false;
      # Games come back from Steam; its images only in a full backup (W2)
      backup = false;
      nat = true;
      enableHostDbusForward = false;
      # First test on the xmg (2026-10-14)
      hosts = [ "xmg" ];
    }
    {
      # dGPU passthrough like steam; not on Xen yet
      name = "godot";
      short = "g";
      label = "dev";
      ip = "10.0.0.13";
      autostart = false;
      nat = true;
      allowGitHubAgent = true;
      features = [ "yazi" ];
      hosts = [ ];
    }
    {
      name = "mirage";
      short = "mi";
      label = "dev";
      ip = "10.0.0.14";
      autostart = false;
      nat = true;
      allowGitHubAgent = true;
      enableHostDbusForward = false;
      hosts = [ ];
    }
    {
      name = "php";
      short = "p";
      label = "dev";
      storeGroup = "dev";
      ip = "10.0.0.15";
      autostart = false;
      nat = true;
      allowGitHubAgent = true;
      enableHostDbusForward = false;
      features = [ "yazi" ];
      hosts = [ "xmg" ];
      # kali tests its apps over the lab bridge (vm-lab attach)
      labTarget = true;
    }
    {
      name = "ruby";
      short = "r";
      label = "dev";
      storeGroup = "dev";
      ip = "10.0.0.16";
      autostart = false;
      nat = true;
      allowGitHubAgent = true;
      enableHostDbusForward = false;
      features = [ "yazi" ];
      hosts = [ "xmg" ];
    }
    {
      name = "nix";
      short = "nix";
      label = "dev";
      ip = "10.0.0.24";
      autostart = false;
      nat = true;
      allowGitHubAgent = true;
      enableHostDbusForward = false;
      features = [ "yazi" ];
      hosts = [ ];
    }
    {
      # Only common-config; software imperatively in the persistent store
      # overlay (standalone store image, no storeGroup)
      name = "vanilla";
      short = "va";
      label = "untrusted";
      ip = "10.0.0.29";
      autostart = false;
      nat = true;
      # First client of sys-vpn (test); remove for the direct uplink via sys-net
      uplink = "sys-vpn";
      allowGitHubAgent = false;
    }
    {
      # VPN gateway (driver domain, killswitch) for VMs with `uplink = "sys-vpn"`;
      # its own uplink goes to sys-net. Provider configs come in by vm-copy
      name = "sys-vpn";
      short = "sv";
      label = "sys";
      storeGroup = "sys";
      ip = "10.0.0.30";
      autostart = false;
      nat = true;
      disposable = true;
      allowGitHubAgent = false;
    }
    {
      # Ad-hoc disposable (`nox disp`): vanilla's setup, empty on every start
      name = "disp";
      short = "d";
      ip = "10.0.0.31";
      autostart = false;
      nat = true;
      disposable = true;
      allowGitHubAgent = false;
      enableHostDbusForward = false;
    }
    {
      # Disposable for `nox backup`: holds the backup disk, no network
      name = "disp-backup";
      short = "db";
      label = "sys";
      storeGroup = "sys";
      ip = "10.0.0.32";
      autostart = false;
      nat = false;
      disposable = true;
      allowGitHubAgent = false;
      enableHostDbusForward = false;
      clipboard = "deny";
      copy = {
        incoming = "deny";
        outgoing = "deny";
      };
    }
    {
      # Firewall between the VMs and sys-net (Qubes model, driver domain):
      # serves `vm-fw` (10.6.0.0/24) for every VM with `nat` (default uplink),
      # sys-vpn, the Whonix-Gateway (vm-whx-ext) and kali (vm-fw, vm-lab);
      # routed to sys-net without NAT; isolation, egress lists, DNS resolver
      name = "sys-firewall";
      short = "sf";
      label = "sys";
      storeGroup = "sys";
      ip = "10.0.0.33";
      autostart = true;
      nat = true;
      uplink = "sys-net";
      disposable = true;
      allowGitHubAgent = false;
      enableHostDbusForward = false;
    }
    # create-vm: registry-vms
  ];

  # Image domains: guests from upstream disk images (Whonix, Kali), not NixOS and
  # not run by microvm.nix (modules/xen-image-domains.nix). Same fields as
  # `vms` where they apply. They have no admin link and no sshd (dom0 calls
  # their fixed rpc services); `ip` only fills the tables of the scripts.
  imageDomains = [
    {
      name = "whonix-gateway";
      short = "wg";
      label = "anon";
      ip = "10.0.0.27";
    }
    {
      name = "whonix-workstation";
      short = "ww";
      label = "anon";
      ip = "10.0.0.28";
    }
    {
      # Kali from the upstream QEMU image (machines/xmg/xen.nix); uplink via
      # sys-net, second vif on the lab bridge (vm-lab) for testing labTarget VMs
      name = "kali";
      short = "k";
      label = "untrusted";
      ip = "10.0.0.8";
      hosts = [ "xmg" ];
    }
  ];

  # Lookups by name cover all VMs (IPs, keys, store groups), also those not on
  # the current machine; the lists per machine come from `forHost` below.
  byName = builtins.listToAttrs (
    map (vm: {
      name = vm.name;
      value = vm;
    }) vms
  );

  byShort = builtins.listToAttrs (
    map (vm: {
      name = vm.short;
      value = vm;
    }) (builtins.filter (vm: vm.short != null) vms)
  );

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

  mkHardware =
    host:
    let
      usbDevices = usbDevicesFor.${host};
      pciDeviceIds = pciDeviceIdsFor.${host};
    in
    {
      pci = {
        deviceIds = pciDeviceIds;
        devicePaths = pciDevicePathsFor.${host};
        vfioIds = (pciDeviceIds.gpu or [ ]) ++ (pciDeviceIds.gpuAudio or [ ]) ++ pciDeviceIds.nic;
      };
      usb = {
        devices = usbDevices;
        byName = builtins.listToAttrs (
          map (device: {
            name = device.name;
            value = device;
          }) usbDevices
        );
        hostAllow = builtins.filter (device: device.policy == "host-allow") usbDevices;
        vmReserved = builtins.filter (device: device.policy == "vm-reserved") usbDevices;
        defaultForOwner =
          owner: builtins.filter (device: (device.defaultOwner or null) == owner) usbDevices;
        allowedForOwner =
          owner: builtins.filter (device: builtins.elem owner (device.allowedOwners or [ ])) usbDevices;
      };
    };

  # The registry as one machine sees it: `vms`/`imageDomains` and everything
  # derived from them only hold what runs there (registry field `hosts`)
  forHost =
    host:
    let
      onHost = entry: builtins.elem host (entry.hosts or [ host ]);
      hostVms = builtins.filter onHost vms;
    in
    {
      inherit host byName byShort;
      vms = hostVms;
      imageDomains = builtins.filter onHost imageDomains;
      natIPs = map (vm: vm.ip) (builtins.filter (vm: vm.nat or false) hostVms);
      autostartNames = map (vm: vm.name) (builtins.filter (vm: vm.autostart or false) hostVms);
      dbusForwardParticipants = builtins.filter (vm: vm.enableHostDbusForward or true) hostVms;
      # W1 backup (vm-backup) preselects these; field `backup`, default false
      # for sys-* and disposables
      backupVms = builtins.filter (
        vm: vm.backup or (!(builtins.substring 0 4 vm.name == "sys-" || (vm.disposable or false)))
      ) hostVms;
      vmHasFeature = feature: builtins.filter (vm: builtins.elem feature (vm.features or [ ])) hostVms;
      globalExtraSSH = [ ];
      hardware = mkHardware host;
      hostProfile = hostProfiles.${host};
    };
in
{
  inherit forHost;
  hosts = builtins.attrNames hostProfiles;
}
