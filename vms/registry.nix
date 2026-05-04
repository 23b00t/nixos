let
  # Central VM registry used across host, home-manager scripts and helper tools.
  # Each VM entry has the following fields:
  #   name        : long name without "-vm" suffix (e.g. "nvim")
  #   short       : short alias used in CLI tools (e.g. "n")
  #   ip          : IPv4 address on the 10.0.0.0/24 network
  #   autostart   : whether the VM should autostart via microvm.host
  #   nat         : whether the VM should be included in networking.nat.internalIPs
  #   allowVmCopy : whether the VM should participate in inter-VM copy; defaults to true
  #   allowGitHubAgent : whether the VM should receive the dedicated forwarded GitHub SSH agent/socket
  #   enableHostDbusForward : whether host should keep persistent forwarded /tmp/ssh_dbus.sock for this VM (defaults to true)
  #   extraSSH    : extra SSH matchOptions for home.ssh (may be [])
  #   features    : arbitrary list of features/tags used for dynamic grouping in helper tools
  vms = [
    {
      name = "nvim";
      short = "n";
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
      ip = "10.0.0.2";
      autostart = true;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqGdw377nJ+Zcf2kXwIiXPi5OFuY5KPOuhi0YaWhGmb chat-vm";
      features = [ "yazi" ];
    }
    # {
    #   name = "test";
    #   short = "t";
    #   ip = "10.0.0.3";
    #   autostart = false;
    #   nat = true;
    #   hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2091GSIL+SlR1BsWswg+6DZzrL+enxmXo74d/OSUwv test-vm";
    # }
    {
      name = "music";
      short = "m";
      ip = "10.0.0.4";
      autostart = true;
      nat = true;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF/ca5rt+rbz5EanCgVCaGQEOco670v/gDm+Op/fM4Y7 music-vm";
    }
    {
      name = "net";
      short = "net";
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
    #   ip = "10.0.0.7";
    #   autostart = false;
    #   nat = true;
    #   hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRYiHWjGyucuX6XJq2U3ENx7MHACcX0t8YzB2JEgfyR wine-vm";
    # }
    # {
    #   name = "kali";
    #   short = "k";
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
      ip = "10.0.0.9";
      autostart = false;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC76Fb5xSeNdZ9BVPf7OdLWhULXgb1OCAgPfYoeLZBl office-vm";
      features = [ "yazi" ];
    }
    {
      name = "vault";
      short = "v";
      ip = "10.0.0.10";
      autostart = false;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINPbWqbgvB7bf39HteuS/bmSDqLuPiZn5AV63fjRXEVw vault-vm";
      features = [ "yazi" ];
    }
    {
      name = "irc";
      short = "i";
      ip = "10.0.0.11";
      autostart = true;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIi5GV6zFAWtdZu3NoVn/48ntuGf6nSpC/eoi5cxJyoZ irc-vm";
    }
    {
      name = "sys-usb";
      short = "su";
      ip = "10.0.0.23";
      autostart = false;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIsMuzfPPoWJ9bgKKPBWx/l5qYuWtwEG5s/yHs4rUrJn sys-usb-vm";
      features = [ "yazi" ];
    }
    {
      name = "sys-net";
      short = "sn";
      ip = "10.0.0.253";
      autostart = true;
      nat = false;
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2rxZHd/9pzQeQz3VDwlpcEP9KGOASXYsajKbcZdJ4/ sys-net-vm";
      allowVmCopy = false;
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
      vendorId = "093a";
      productId = "2533";
      policy = "host-allow";
      defaultOwner = "host";
      allowedOwners = [
        "host"
        "steam"
      ];
      microvmUsbPath = "vendorid=0x093a,productid=0x2533";
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

  pciDeviceIds = {
    nic = [
      # TODO:
    ];
  };

  pciDevicePaths = {
    nic = [
      # TODO:
    ];
  };

  pciVfioIds = pciDeviceIds.gpu ++ pciDeviceIds.gpuAudio ++ pciDeviceIds.nic;

  hostProfile = {
    cpuVendor = "amd";
    blockedHostDrivers = {
      # TODO:
      nic = [ "" ];
      wifi = [ "" ];
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
