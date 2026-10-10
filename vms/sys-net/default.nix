# sys-net (v2.5): Xen HVM driver domain owning the WLAN card. Serves the
# uplink bridge `vm-uplink` (10.1.0.254/24) as backend for the VMs' uplink vifs
# and NATs it to the WLAN. dom0 is only on the admin network (vm-lan).
{ lib, pkgs, ... }:
let
  vmRegistry = import ../registry.nix;
  nicPciPaths = vmRegistry.hardware.pci.devicePaths.nic or [ ];
  mkPciDevice = path: {
    bus = "pci";
    inherit path;
  };
  dom0 = "10.0.0.254";
  dom0TestAccess = vmRegistry.hostProfile.dom0TestAccess or null;
  # sys-print (C2) on the uplink: 10.1.0.<last octet of its registry IP>
  sysPrint = "10.1.0.${lib.last (lib.splitString "." vmRegistry.byName.sys-print.ip)}";
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/wprs.nix
  ];

  networking.hostName = "sys-net-vm";

  services = {
    net-config = {
      enable = true;
      tapId = "vm-router";
      interfaceName = "vm-lan";
      address4 = "10.0.0.253/24";
      gateway4 = null;
      mac = "00:00:00:00:00:11";
    };

    common-config = {
      enable = true;
      withDefaultPkgs = false;
      vmCopy.enable = false;
    };

    # SSH only from the admin network (dom0), not from the uplink or the WLAN
    openssh.openFirewall = false;
  };

  users.users.user.extraGroups = lib.mkAfter [ "networkmanager" ];

  # Uplink bridge; the vif-bridge hotplug script (xl devd) adds the VMs' vifs
  systemd.network = {
    netdevs."20-vm-uplink".netdevConfig = {
      Name = "vm-uplink";
      Kind = "bridge";
    };
    networks = {
      "30-vm-uplink" = {
        matchConfig.Name = "vm-uplink";
        address = [ "10.1.0.254/24" ];
        networkConfig.ConfigureWithoutCarrier = true;
        linkConfig.RequiredForOnline = "no";
      };
      # Bridge membership of the vifs is up to the hotplug script
      "10-vif" = {
        matchConfig.Name = "vif*";
        linkConfig.Unmanaged = true;
      };
    };
  };

  networking = {
    networkmanager = {
      enable = true;
      unmanaged = [
        "interface-name:vm-lan"
        "interface-name:vm-uplink"
        "interface-name:vif*"
      ];
    };
    nftables = {
      enable = true;
      tables = {
        # VMs on the uplink reach sys-net and the outside, never each other
        uplink-isolation = {
          family = "bridge";
          content = ''
            chain forward {
              # priority 0 would be skipped: br_netfilter re-injects after its own hook (prio 0)
              type filter hook forward priority filter; policy accept;
              iifname "vif*" oifname "vif*" drop
            }
          '';
        };
      }
      // lib.optionalAttrs (dom0TestAccess != null) {
        # Test phase: SSH from the LAN to dom0
        dom0-ssh = {
          family = "ip";
          content = ''
            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;
              iifname "wl*" ip saddr ${dom0TestAccess.lan} tcp dport 22 dnat to ${dom0}:22
            }
          '';
        };
      };
    };
    firewall = {
      enable = true;
      interfaces.vm-lan.allowedTCPPorts = [ 22 ];
      filterForward = true;
      extraForwardRules = ''
        # sys-print (C2): printers in the local network (IPP), nothing else
        iifname "vm-uplink" ip saddr ${sysPrint} oifname != { "vm-uplink", "vm-lan" } ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } tcp dport 631 accept
        iifname "vm-uplink" ip saddr ${sysPrint} reject with icmpx type admin-prohibited
        # VMs -> outside only (not into the admin network)
        iifname "vm-uplink" oifname != { "vm-uplink", "vm-lan" } accept
      ''
      + lib.optionalString (dom0TestAccess != null) ''
        # Test phase: dom0 -> outside, HTTPS/DNS/NTP/ICMP only (as on the XMG),
        # never into the uplink network
        iifname "vm-lan" ip saddr ${dom0} oifname "vm-uplink" reject with icmpx type admin-prohibited
        iifname "vm-lan" ip saddr ${dom0} meta l4proto icmp accept
        iifname "vm-lan" ip saddr ${dom0} tcp dport { 22, 80, 443 } accept
        iifname "vm-lan" ip saddr ${dom0} udp dport { 53, 123 } accept
        iifname "vm-lan" ip saddr ${dom0} tcp dport 53 accept
        iifname "vm-lan" ip saddr ${dom0} reject with icmpx type admin-prohibited
        # Test phase: LAN -> dom0 SSH (port forward above)
        iifname "wl*" oifname "vm-lan" ip saddr ${dom0TestAccess.lan} ip daddr ${dom0} tcp dport 22 ct status dnat accept
      ''
      + ''
        ct state established,related accept
      '';
    };
    nat = {
      enable = true;
      internalInterfaces = [ "vm-uplink" ] ++ lib.optional (dom0TestAccess != null) "vm-lan";
    };
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # MSI-X mapping fails for passthrough with a PVH dom0 (v2.1); INTx works
  boot.kernelParams = [ "pci=nomsi" ];

  # RTL8821CE (rtw88): the firmware got stuck in power save ("firmware failed
  # to leave lps state", "failed to send h2c command"), downloads at ~10 KB/s
  # (2026-10-10). No power save, no deep LPS, no ASPM.
  networking.networkmanager.wifi.powersave = false;
  boot.extraModprobeConfig = ''
    options rtw88_core disable_lps_deep=y
    options rtw88_pci disable_aspm=y
  '';

  hardware.enableRedistributableFirmware = true;

  systemd.services.NetworkManager-wait-online.enable = false;

  microvm = {
    hypervisor = "xen";
    xen = {
      # PCI passthrough with a PVH dom0 only works for HVM guests
      type = "hvm";
      driverDomain = true;
    };
    volumes = [
      {
        mountPoint = "/etc/NetworkManager/system-connections";
        image = "networkmanager.img";
        size = 512;
      }
    ];
    devices = map mkPciDevice nicPciPaths;
    mem = 1024;
  };

  environment.systemPackages = with pkgs; [
    networkmanager
    networkmanagerapplet
    iw
    ethtool
    iproute2
    wirelesstools
    wpa_supplicant
    dnsutils
    tcpdump
    nftables
    iftop
  ];

  system.stateVersion = "26.05";
}
