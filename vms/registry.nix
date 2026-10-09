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
      name = "music";
      short = "m";
      storeGroup = "desktop";
      ip = "10.0.0.4";
      autostart = true;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF/ca5rt+rbz5EanCgVCaGQEOco670v/gDm+Op/fM4Y7 music-vm";
    }
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
    # {
    #   name = "wine";
    #   short = "w";
    #   storeGroup = "prop";
    #   ip = "10.0.0.7";
    #   autostart = false;
    #   nat = true;
    #   hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRYiHWjGyucuX6XJq2U3ENx7MHACcX0t8YzB2JEgfyR wine-vm";
    # }
    # {
    #   name = "kali";
    #   short = "k";
    #   storeGroup = "dev";
    #   ip = "10.0.0.8";
    #   autostart = false;
    #   nat = true;
    #   hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWLTApfkMyJatXN+xw4HAvSq9MH8fBjf7kxj2dOZmV+ kali-vm";
    #   enableHostDbusForward = false;
    #   features = [ "yazi" ];
    # }
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
    # create-vm: registry-vms
  ];

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

  natIPs = map (vm: vm.ip) (builtins.filter (vm: vm.nat or false) vms);
  autostartNames = map (vm: vm.name) (builtins.filter (vm: vm.autostart or false) vms);
  vmCopyParticipants = builtins.filter (vm: vm.allowVmCopy or true) vms;
  dbusForwardParticipants = builtins.filter (vm: vm.enableHostDbusForward or true) vms;
  vmHasFeature = feature: builtins.filter (vm: builtins.elem feature (vm.features or [ ])) vms;
  globalExtraSSH = [ ];

  # Central USB/Bluetooth inventory and ownership policy.
  usbDevices = [
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
    # {
    #   name = "bluetooth-ax211";
    #   vendorId = "8087";
    #   productId = "0033";
    #   policy = "vm-reserved";
    #   defaultOwner = "sys-usb";
    #   allowedOwners = [
    #     "sys-usb"
    #     "steam"
    #   ];
    #   microvmUsbPath = "vendorid=0x8087,productid=0x0033";
    #   udev = {
    #     group = "kvm";
    #     mode = "0660";
    #   };
    # }
    # {
    #   name = "webcam-main";
    #   vendorId = "2b7e";
    #   productId = "c906";
    #   policy = "vm-reserved";
    #   defaultOwner = "chat";
    #   allowedOwners = [ "chat" ];
    #   microvmUsbPath = "vendorid=0x2b7e,productid=0xc906";
    #   udev = {
    #     group = "kvm";
    #   };
    # }
    # {
    #   name = "monitor-hub-main";
    #   vendorId = "05e3";
    #   productId = "0620";
    #   policy = "host-allow";
    #   defaultOwner = "host";
    #   allowedOwners = [ "host" ];
    #   allowChildren = false;
    #   preserveDisplayPlumbing = true;
    #   microvmUsbPath = "vendorid=0x05e3,productid=0x0620";
    # }
    # {
    #   name = "ite-8291";
    #   vendorId = "048d";
    #   productId = "600b";
    #   policy = "host-allow";
    #   defaultOwner = "host";
    #   allowedOwners = [ "host" ];
    #   internal = true;
    #   microvmUsbPath = "vendorid=0x048d,productid=0x600b";
    # }
    # hp (Xen, v2.6): both xHCI controllers belong to sys-usb. Owner `host` =
    # input device forwarded to dom0 by the input proxy; another VM as owner =
    # exported via USB/IP; owner `sys-usb` = stays there.
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
    {
      name = "verbatim usb-stick";
      vendorId = "18a5";
      productId = "0243";
      policy = "vm-reserved";
      defaultOwner = "sys-usb";
      allowedOwners = [ "sys-usb" ];
      microvmUsbPath = "vendorid=0x18a5,productid=0x0243";
      udev = {
        group = "kvm";
        mode = "0660";
        udisksIgnore = true;
      };
    }
  ];

  usbByName = builtins.listToAttrs (
    map (device: {
      name = device.name;
      value = device;
    }) usbDevices
  );

  hostAllowUsb = builtins.filter (device: device.policy == "host-allow") usbDevices;
  vmReservedUsb = builtins.filter (device: device.policy == "vm-reserved") usbDevices;
  defaultUsbForOwner =
    owner: builtins.filter (device: (device.defaultOwner or null) == owner) usbDevices;
  allowedUsbForOwner =
    owner: builtins.filter (device: builtins.elem owner (device.allowedOwners or [ ])) usbDevices;

  # Xen: passed-through devices go to pciback (`xl pci-assignable-add` when the
  # VM starts), not vfio-pci, so they don't belong in the vfio ids
  pciDeviceIds = {
    nic = [ ];
  };

  pciDevicePaths = {
    nic = [
      "0000:01:00.0" # RTL8821CE WLAN (10ec:c821) -> sys-net
    ];
    usb = [
      "0000:03:00.3" # xHCI (1022:1639): webcam, Bluetooth -> sys-usb
      "0000:03:00.4" # xHCI (1022:1639): fingerprint, external ports -> sys-usb
    ];
  };

  pciVfioIds = (pciDeviceIds.gpu or [ ]) ++ (pciDeviceIds.gpuAudio or [ ]) ++ pciDeviceIds.nic;

  hostProfile = {
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

  hardware = {
    pci = {
      deviceIds = pciDeviceIds;
      devicePaths = pciDevicePaths;
      vfioIds = pciVfioIds;
    };
    usb = {
      devices = usbDevices;
      byName = usbByName;
      hostAllow = hostAllowUsb;
      vmReserved = vmReservedUsb;
      defaultForOwner = defaultUsbForOwner;
      allowedForOwner = allowedUsbForOwner;
    };
  };
in
{
  inherit
    vms
    byName
    byShort
    natIPs
    autostartNames
    vmCopyParticipants
    dbusForwardParticipants
    globalExtraSSH
    hardware
    hostProfile
    vmHasFeature
    ;
}
