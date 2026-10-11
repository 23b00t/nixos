let
  # Central VM registry used across host, home-manager scripts and helper tools.
  # Each VM entry has the following fields:
  #   name        : long name without "-vm" suffix (e.g. "nvim")
  #   short       : short alias used in CLI tools (e.g. "n")
  #   ip          : IPv4 address on the 10.0.0.0/24 network
  #   autostart   : whether the VM should autostart via microvm.host
  #   restartIfChanged: whether the VM should be automatically restarted if its configuration changes; defaults to true
  #   nat         : whether the VM should be included in networking.nat.internalIPs
  #   allowVmCopy : whether the VM should participate in inter-VM copy; defaults to true
  #   allowGitHubAgent : whether the VM should receive the dedicated forwarded GitHub SSH agent/socket
  #   enableHostDbusForward : whether host should keep persistent forwarded /tmp/ssh_dbus.sock for this VM (defaults to true)
  #   extraSSH    : extra SSH matchOptions for home.ssh (may be [])
  #   features    : arbitrary list of features/tags used for dynamic grouping in helper tools
  #   storeGroup  : shared read-only store image (vms/store-groups.nix): "sys" | "dev" | "desktop" | "prop"; absent = own image
  #   memPriority : RAM balancer priority when host RAM is short (modules/xen-memory.nix); higher grows first, default 0
  #   hosts       : machines that run this VM (`forHost` below); absent = all machines, [ ] = none (definition kept)
  vms = [
    {
      name = "nvim";
      short = "n";
      storeGroup = "dev";
      ip = "10.0.0.1";
      autostart = true;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzJjZw0V2CdaWI/IBFcTQPwQhYtFn/31i5iNPSc1j8G nvim-vm";
      allowGitHubAgent = true;
      features = [ "yazi" ];
    }
    {
      name = "chat";
      short = "c";
      storeGroup = "prop";
      ip = "10.0.0.2";
      autostart = true;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqGdw377nJ+Zcf2kXwIiXPi5OFuY5KPOuhi0YaWhGmb chat-vm";
      features = [ "yazi" ];
    }
    # {
    #   name = "test";
    #   short = "t";
    #   storeGroup = "dev";
    #   ip = "10.0.0.3";
    #   autostart = false;
    #   nat = true;
    #   hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2091GSIL+SlR1BsWswg+6DZzrL+enxmXo74d/OSUwv test-vm";
    # }
    {
      name = "net";
      short = "net";
      storeGroup = "desktop";
      ip = "10.0.0.5";
      autostart = true;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1NctcWQx10E7C96SSb9LSDqFln/7g82rFnRfsPLpFX net-vm";
      features = [ "yazi" ];
    }
    {
      name = "coding";
      short = "cc";
      ip = "10.0.0.6";
      autostart = true;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO9Co+A8G16ciSIU3vldErgRNpmZ+JVHzsj2oNteV1e+ coding-vm";
      allowGitHubAgent = true;
      enableHostDbusForward = true;
      features = [ "yazi" ];
    }
    {
      name = "wine";
      short = "w";
      storeGroup = "prop";
      ip = "10.0.0.7";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRYiHWjGyucuX6XJq2U3ENx7MHACcX0t8YzB2JEgfyR wine-vm";
      hosts = [ ];
    }
    {
      name = "kali";
      short = "k";
      storeGroup = "dev";
      ip = "10.0.0.8";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWLTApfkMyJatXN+xw4HAvSq9MH8fBjf7kxj2dOZmV+ kali-vm";
      enableHostDbusForward = false;
      features = [ "yazi" ];
      hosts = [ ];
    }
    {
      name = "office";
      short = "o";
      storeGroup = "desktop";
      ip = "10.0.0.9";
      autostart = false;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC76Fb5xSeNdZ9BVPf7OdLWhULXgb1OCAgPfYoeLZBl office-vm";
      features = [ "yazi" ];
    }
    {
      name = "vault";
      short = "v";
      storeGroup = "desktop";
      ip = "10.0.0.10";
      autostart = false;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINPbWqbgvB7bf39HteuS/bmSDqLuPiZn5AV63fjRXEVw vault-vm";
      features = [ "yazi" ];
    }
    {
      name = "irc";
      short = "i";
      storeGroup = "desktop";
      ip = "10.0.0.11";
      autostart = true;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIi5GV6zFAWtdZu3NoVn/48ntuGf6nSpC/eoi5cxJyoZ irc-vm";
    }
    {
      name = "sys-usb";
      short = "su";
      storeGroup = "sys";
      ip = "10.0.0.23";
      autostart = false;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIsMuzfPPoWJ9bgKKPBWx/l5qYuWtwEG5s/yHs4rUrJn sys-usb-vm";
      features = [ "yazi" ];
    }
    {
      name = "sys-net";
      short = "sn";
      storeGroup = "sys";
      ip = "10.0.0.253";
      autostart = true;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2rxZHd/9pzQeQz3VDwlpcEP9KGOASXYsajKbcZdJ4/ sys-net-vm";
      allowVmCopy = false;
    }
    {
      name = "builder";
      short = "b";
      ip = "10.0.0.25";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINX+ZshJR9vhy9Fq1J6VteXQASQhNEzFtQ1bV1L+j1eY builder-vm";
      allowGitHubAgent = false;
      enableHostDbusForward = false;
      allowVmCopy = false;
      memPriority = 10;
    }
    {
      # Print driver domain (C2): CUPS with driverless queues, PDFs come in
      # over RPC (`vm-print`), network only to LAN printers (sys-net)
      name = "sys-print";
      short = "sp";
      storeGroup = "sys";
      ip = "10.0.0.26";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBFHr1LwubMtQkVi+fFAkZUvJSL68pMSoQ6hE7Av57t sys-print-vm";
      allowGitHubAgent = false;
      enableHostDbusForward = false;
      allowVmCopy = false;
    }
    {
      # dGPU passthrough (v4, after the XMG migration); not on Xen yet
      name = "steam";
      short = "s";
      ip = "10.0.0.12";
      autostart = false;
      nat = true;
      enableHostDbusForward = false;
      hosts = [ ];
    }
    {
      # dGPU passthrough like steam; not on Xen yet
      name = "godot";
      short = "g";
      ip = "10.0.0.13";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhv6q3siBUASk16LN8tCa2nPUp4g2isRuwo1ndDPz7g godot-vm";
      allowGitHubAgent = true;
      features = [ "yazi" ];
      hosts = [ ];
    }
    {
      name = "mirage";
      short = "mi";
      ip = "10.0.0.14";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAXSVOR0aTAo/5lDeG+3r3QeOygbLKY7WrkB8wSK+rh9 mirage-vm";
      allowGitHubAgent = true;
      enableHostDbusForward = false;
      hosts = [ ];
    }
    {
      name = "php";
      short = "p";
      storeGroup = "dev";
      ip = "10.0.0.15";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHpfcEv27hamz0HELXGKpLd6M+/m5m/fopZ3A7fonUVw php-vm";
      allowGitHubAgent = true;
      enableHostDbusForward = false;
      features = [ "yazi" ];
      hosts = [ "xmg" ];
    }
    {
      name = "ruby";
      short = "r";
      storeGroup = "dev";
      ip = "10.0.0.16";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAkF7qniIZVKtoIrUUWkU8t/1QeK34BSEgI54MbqbieC ruby-vm";
      allowGitHubAgent = true;
      enableHostDbusForward = false;
      features = [ "yazi" ];
      hosts = [ "xmg" ];
    }
    {
      name = "nix";
      short = "nix";
      ip = "10.0.0.24";
      autostart = false;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK1BBz8Jz9CHLkp7C7gfxG+HuEfj+PK+xXxiJGh2pE+H nix-vm";
      allowGitHubAgent = true;
      enableHostDbusForward = false;
      features = [ "yazi" ];
      hosts = [ ];
    }
    # create-vm: registry-vms
  ];

  # Image domains: guests from upstream disk images (Whonix), not NixOS and
  # not run by microvm.nix (modules/xen-image-domains.nix). Same fields as
  # `vms` where they apply. They have no admin link: `ip` is only the SSH
  # alias (SSH goes over vchan), `hostSSHKey` the key dom0 logs in with.
  imageDomains = [
    {
      name = "whonix-gateway";
      short = "wg";
      ip = "10.0.0.27";
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBe5ZZwbEfjSY57zWxpsfQy50IzEF651mYCHBKw0MfK whonix-gateway-vm";
    }
    {
      name = "whonix-workstation";
      short = "ww";
      ip = "10.0.0.28";
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFmHyoO9EqyunijIaireMd0WtyGrasDwRrFx9R5NvF2B whonix-workstation-vm";
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
      # Ethernet only for now: CNVi WLAN (00:14.3, 8086:7a70) is a function of
      # the same device as the xHCI that goes to sys-usb (shared INTx with
      # pci=nomsi). Pass it through later as a separate test step.
      nic = [
        "0000:05:00.0" # RTL8125 Ethernet (10ec:8125) -> sys-net
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
      # Blacklists nouveau/nvidia in dom0, the dGPU stays unbound for steam
      dGpuVendor = "nvidia";
      blockedHostDrivers = {
        # dom0 never drives the NICs; sys-net owns them
        nic = [ "r8169" ];
        wifi = [ "iwlwifi" ];
      };
      # Migration phase: dom0 keeps internet through sys-net as on hp
      dom0TestAccess = {
        lan = "192.168.178.0/24";
      };
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
      vmCopyParticipants = builtins.filter (vm: vm.allowVmCopy or true) hostVms;
      dbusForwardParticipants = builtins.filter (vm: vm.enableHostDbusForward or true) hostVms;
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
