# sys-usb (v2.6): Xen HVM driver domain owning all USB controllers. Keeps
# Bluetooth and storage, exports USB devices of other VMs via USB/IP on the
# link bridge `vm-usbip`, and offers the allowed input devices to dom0's
# input proxy (vms/usb-links.nix, modules/xen-usb.nix).
{
  lib,
  pkgs,
  config,
  ...
}:
let
  vmRegistry = import ../registry.nix;
  links = import ../usb-links.nix { inherit lib vmRegistry; };
  usbPciPaths = vmRegistry.hardware.pci.devicePaths.usb or [ ];
  mkPciDevice = path: {
    bus = "pci";
    inherit path;
  };
  usbip = config.boot.kernelPackages.usbip;

  # `usbip-release <vendor:product>...` (run by dom0's xen-links when a
  # consumer VM went away): re-export devices still marked as used by a
  # vanished client (usbip_status 2), by restarting their usbip-bind unit
  usbipRelease = pkgs.writeShellScriptBin "usbip-release" ''
    for vp in "$@"; do
      [[ "$vp" =~ ^[0-9a-f]{4}:[0-9a-f]{4}$ ]] || { echo "invalid id: $vp" >&2; continue; }
      for dev in /sys/bus/usb/devices/*; do
        [ -f "$dev/idVendor" ] && [ -f "$dev/usbip_status" ] || continue
        [ "$(<"$dev/idVendor"):$(<"$dev/idProduct")" = "$vp" ] || continue
        if [ "$(<"$dev/usbip_status")" = 2 ]; then
          echo "releasing $vp (busid ''${dev##*/})"
          ${pkgs.systemd}/bin/systemctl restart "usbip-bind@''${dev##*/}.service"
        fi
      done
    done
  '';

  # Exported devices: bind to usbip-host as soon as they appear (busid = %k)
  usbipBindRules = lib.concatMapStrings (d: ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="${d.vendorId}", ATTR{idProduct}=="${d.productId}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="usbip-bind@%k.service"
  '') links.exported;

  # Input devices for dom0: stable names under /dev/input-proxy, readable by
  # the input-proxy group only (dom0 connects as `user`)
  inputProxyRules = lib.concatMapStrings (d: ''
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="${d.vendorId}", ATTRS{idProduct}=="${d.productId}", SYMLINK+="input-proxy/${d.vendorId}-${d.productId}-%k", GROUP="input-proxy", MODE="0640"
  '') links.inputDevices;
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/yazi-config.nix
    ../modules/wprs.nix
  ];

  networking.hostName = "sys-usb-vm";

  services = {
    net-config = {
      enable = true;
      index = 23;
      mac = "00:00:00:00:00:fc";
      interfaceName = "vm-lan";
    };

    common-config = {
      enable = true;
      withDefaultPkgs = false;
    };

    # SSH only from the admin network (dom0)
    openssh.openFirewall = false;

    udev.extraRules = usbipBindRules + inputProxyRules;

    dbus.enable = true;
    udisks2.enable = true;
    blueman.enable = true;
    pulseaudio = {
      enable = true;
      package = pkgs.pulseaudioFull;
      extraConfig = ''
        load-module module-switch-on-connect
      '';
    };
  };

  users.groups.input-proxy = { };
  users.users.user.extraGroups = lib.mkAfter [ "input-proxy" ];

  boot = {
    kernelModules = [
      "btusb"
      "btintel"
      "usbip-host"
    ];
    # MSI-X mapping fails for passthrough with a PVH dom0 (v2.1); INTx works
    kernelParams = [ "pci=nomsi" ];
  };

  # USB/IP link: VMs' vifs are added by the hotplug script (xl devd)
  systemd.network = {
    netdevs."20-${links.bridge}".netdevConfig = {
      Name = links.bridge;
      Kind = "bridge";
    };
    networks = {
      "30-${links.bridge}" = {
        matchConfig.Name = links.bridge;
        address = [ "${links.serverAddress}/${toString links.prefixLength}" ];
        networkConfig.ConfigureWithoutCarrier = true;
        linkConfig.RequiredForOnline = "no";
      };
      "10-vif" = {
        matchConfig.Name = "vif*";
        linkConfig.Unmanaged = true;
      };
    };
  };

  systemd.services = {
    usbipd = {
      description = "USB/IP server (devices exported to other VMs)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${usbip}/bin/usbipd -4";
        Restart = "always";
      };
    };

    "usbip-bind@" = {
      description = "Export USB device %i via USB/IP";
      after = [ "usbipd.service" ];
      requires = [ "usbipd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${usbip}/bin/usbip bind -b %i";
        ExecStop = "-${usbip}/bin/usbip unbind -b %i";
      };
    };
  };

  networking = {
    nftables = {
      enable = true;
      # VMs on the USB/IP link reach sys-usb, never each other
      tables.usbip-isolation = {
        family = "bridge";
        content = ''
          chain forward {
            # priority 0 would be skipped: br_netfilter re-injects after its own hook (prio 0)
            type filter hook forward priority filter; policy accept;
            iifname "vif*" oifname "vif*" drop
          }
        '';
      };
    };
    firewall = {
      enable = true;
      interfaces.vm-lan.allowedTCPPorts = [ 22 ];
      # usbipd only for the VMs that own exported devices
      extraInputRules = lib.optionalString (links.consumers != [ ]) ''
        iifname "${links.bridge}" ip saddr { ${
          lib.concatMapStringsSep ", " links.addressOf links.consumers
        } } tcp dport ${toString links.port} accept
      '';
    };
  };

  microvm = {
    hypervisor = "xen";
    xen = {
      # PCI passthrough with a PVH dom0 only works for HVM guests
      type = "hvm";
      driverDomain = true;
    };
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 10000;
      }
    ];
    devices = map mkPciDevice usbPciPaths;
    mem = 1024;
    vcpu = 1;
  };

  environment.systemPackages = with pkgs; [
    blueman
    bluez
    bluez-tools
    dbus
    dosfstools
    exfatprogs
    exfat
    ntfs3g
    parted
    udisks2
    usbutils
    util-linux
    usbip
    usbipRelease
    netevent
  ];

  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          subject.isInGroup("wheel") &&
          action.id.indexOf("org.freedesktop.udisks2.") == 0
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };
  programs.dconf.enable = true;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
        Enable = "Source,Sink,Media,Socket";
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  system.stateVersion = "26.05";
}
