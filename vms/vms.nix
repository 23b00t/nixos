# The user's domains (NoX schema `nox.vms` / `nox.images`, NoX
# nixos/registry/vms.nix; field descriptions there). `host` is the machine
# the registry is evaluated for: `enable = host == "xmg"` runs a VM only
# there (enable = false: definition kept, nowhere).
{ host, ... }:
{
  nox.vms = {
    nvim = {
      index = 1;
      short = "n";
      label = "dev";
      storeGroup = "dev";
      autostart = true;
      githubAgent = true;
      features = [ "yazi" ];
    };
    chat = {
      index = 2;
      short = "c";
      label = "personal";
      storeGroup = "prop";
      autostart = true;
      features = [ "yazi" ];
    };
    net = {
      index = 5;
      short = "net";
      label = "untrusted";
      storeGroup = "desktop";
      autostart = true;
      features = [ "yazi" ];
    };
    coding = {
      index = 6;
      short = "cc";
      label = "dev";
      autostart = true;
      githubAgent = true;
      dbus = true;
      features = [ "yazi" ];
      # kali tests its apps over the lab bridge (vm-lab attach)
      labTarget = true;
    };
    # Windows apps (Bottles, no gaming); internet, but no session bus and
    # no GitHub agent
    win = {
      index = 7;
      short = "w";
      label = "untrusted";
      storeGroup = "prop";
      githubAgent = false;
      dbus = false;
    };
    office = {
      index = 9;
      short = "o";
      label = "personal";
      storeGroup = "desktop";
      uplink = null;
      features = [ "yazi" ];
    };
    vault = {
      index = 10;
      short = "v";
      label = "vault";
      storeGroup = "desktop";
      uplink = null;
      clipboard = "ask";
      copy.incoming = "warn";
      features = [ "yazi" ];
    };
    irc = {
      index = 11;
      short = "i";
      label = "personal";
      storeGroup = "desktop";
      autostart = true;
      uplink = null;
    };
    sys-usb = {
      index = 23;
      short = "su";
      label = "sys";
      storeGroup = "sys";
      uplink = null;
      disposable = true;
      features = [ "yazi" ];
    };
    sys-net = {
      index = 253;
      short = "sn";
      label = "sys";
      storeGroup = "sys";
      autostart = true;
      uplink = null;
      disposable = true;
    };
    builder = {
      index = 25;
      short = "b";
      label = "sys";
      hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINX+ZshJR9vhy9Fq1J6VteXQASQhNEzFtQ1bV1L+j1eY builder-vm";
      githubAgent = false;
      dbus = false;
      memPriority = 10;
      # nothing in or out by nox-rpc copy (the build VM sees untrusted code)
      copy = {
        incoming = "deny";
        outgoing = "deny";
      };
    };
    # Print driver domain (C2): CUPS with driverless queues, PDFs come in
    # over RPC (`vm-print`), network only to LAN printers (sys-net)
    sys-print = {
      index = 26;
      short = "sp";
      label = "sys";
      storeGroup = "sys";
      # Prints into the local network: its rule lives in sys-net (IPP to the LAN)
      uplink = "sys-net";
      # holds no user data: print jobs only
      copy = {
        incoming = "deny";
        outgoing = "deny";
      };
      githubAgent = false;
      dbus = false;
    };
    # Xen HVM with the dGPU (PCI passthrough); input and Bluetooth via
    # USB/IP from sys-usb (`vm-usb attach <device> steam`)
    steam = {
      enable = host == "xmg";
      index = 12;
      short = "s";
      label = "untrusted";
      # Games come back from Steam; its images only in a full backup
      backup = false;
      dbus = false;
    };
    # dGPU passthrough like steam; not on Xen yet
    godot = {
      enable = false;
      index = 13;
      short = "g";
      label = "dev";
      githubAgent = true;
      features = [ "yazi" ];
    };
    mirage = {
      enable = false;
      index = 14;
      short = "mi";
      label = "dev";
      githubAgent = true;
      dbus = false;
    };
    php = {
      enable = host == "xmg";
      index = 15;
      short = "p";
      label = "dev";
      storeGroup = "dev";
      githubAgent = true;
      dbus = false;
      features = [ "yazi" ];
      # kali tests its apps over the lab bridge (vm-lab attach)
      labTarget = true;
    };
    ruby = {
      enable = host == "xmg";
      index = 16;
      short = "r";
      label = "dev";
      storeGroup = "dev";
      githubAgent = true;
      dbus = false;
      features = [ "yazi" ];
    };
    nix = {
      enable = false;
      index = 24;
      short = "nix";
      label = "dev";
      githubAgent = true;
      dbus = false;
      features = [ "yazi" ];
    };
    # Only common-config; software imperatively in the persistent store
    # overlay (standalone store image, no storeGroup)
    vanilla = {
      role = "minimal";
      module = ./vanilla.nix;
      index = 29;
      short = "va";
      label = "untrusted";
      memory = 2048;
      memoryMax = 4096;
      vcpu = 1;
      home.size = 20000;
      # First client of sys-vpn (test); remove for the direct uplink via sys-firewall
      uplink = "sys-vpn";
      githubAgent = false;
    };
    # VPN gateway (driver domain, killswitch) for VMs with `uplink = "sys-vpn"`;
    # its own uplink goes to sys-net. Provider configs come in by vm-copy
    sys-vpn = {
      index = 30;
      short = "sv";
      label = "sys";
      storeGroup = "sys";
      disposable = true;
      githubAgent = false;
    };
    # Ad-hoc disposable (`nox disp`): vanilla's setup, empty on every start
    disp = {
      index = 31;
      short = "d";
      disposable = true;
      githubAgent = false;
      dbus = false;
    };
    # Disposable for `nox backup`: holds the backup disk, no network
    disp-backup = {
      index = 32;
      short = "db";
      label = "sys";
      storeGroup = "sys";
      uplink = null;
      disposable = true;
      githubAgent = false;
      dbus = false;
      clipboard = "deny";
      copy = {
        incoming = "deny";
        outgoing = "deny";
      };
    };
    # Firewall between the VMs and sys-net (Qubes model, driver domain):
    # serves `vm-fw` (10.6.0.0/24) for every VM with the default uplink,
    # sys-vpn, the Whonix-Gateway (vm-whx-ext) and kali (vm-fw, vm-lab);
    # routed to sys-net without NAT; isolation, egress lists, DNS resolver
    sys-firewall = {
      index = 33;
      short = "sf";
      label = "sys";
      storeGroup = "sys";
      autostart = true;
      uplink = "sys-net";
      disposable = true;
      githubAgent = false;
      dbus = false;
    };
  };

  # Image domains: guests from upstream disk images (Whonix, Kali), not NixOS and
  # not run by microvm.nix (NoX modules/xen-image-domains.nix). They have no
  # admin link and no sshd (dom0 calls their fixed rpc services); the index
  # only fills the tables of the scripts.
  nox.images = {
    whonix-gateway = {
      index = 27;
      short = "wg";
      label = "anon";
    };
    whonix-workstation = {
      index = 28;
      short = "ww";
      label = "anon";
    };
    # Kali from the upstream QEMU image (machines/xmg/xen.nix); uplink via
    # sys-net, second vif on the lab bridge (vm-lab) for testing labTarget VMs
    kali = {
      enable = host == "xmg";
      index = 8;
      short = "k";
      label = "untrusted";
    };
  };
}
