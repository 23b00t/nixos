# The user's domains (NoX schema `nox.vms` / `nox.images`, NoX
# nixos/registry/vms.nix; field descriptions there). `host` is the machine
# the registry is evaluated for: `enable = host == "xmg"` runs a VM only
# there (enable = false: definition kept, nowhere).
{ host, lib, ... }:
{
  imports = [ ./apps.nix ];

  nox = {
    # Additions to NoX's roles: claude-code in every dev VM, so the dev store
    # group holds unfree software
    roles.dev.module = ./roles/dev.nix;
    storeGroups.dev.unfree = true;

    # Every VM: time zone and German formats like dom0
    # (machines/common-configuration.nix)
    vmModule =
      { config, lib, ... }:
      lib.mkIf config.services.common-config.enable {
        time.timeZone = "Europe/Berlin";
        i18n.extraLocaleSettings = {
          LC_TIME = "de_DE.UTF-8";
          LC_MONETARY = "de_DE.UTF-8";
          LC_NUMERIC = "de_DE.UTF-8";
          LC_MEASUREMENT = "de_DE.UTF-8";
          LC_PAPER = "de_DE.UTF-8";
          LC_ADDRESS = "de_DE.UTF-8";
          LC_TELEPHONE = "de_DE.UTF-8";
          LC_NAME = "de_DE.UTF-8";
          LC_IDENTIFICATION = "de_DE.UTF-8";
        };
      };

    # NoX infrastructure besides sys-net, sys-usb and sys-firewall
    infra = {
      sys-vpn.enable = true;
      sys-print.enable = true;
      disp.enable = true;
      disp-backup.enable = true;
      builder.enable = true;
    };

    vms = {
      nvim = {
        role = "dev";
        module = ./nvim.nix;
        memory = 2048;
        memoryMax = 4096;
        vcpu = 2;
        home.size = 10000;
        index = 1;
        short = "n";
        label = "dev";
        storeGroup = "dev";
        autostart = true;
        githubAgent = true;
      };
      chat = {
        role = "desktop";
        module = ./chat.nix;
        index = 2;
        short = "c";
        label = "personal";
        storeGroup = "prop";
        autostart = true;
        memory = 4096;
        memoryMax = 8192;
        vcpu = 4;
        home.size = 4096;
        apps = {
          vesktop = {
            install = false;
            tray = true;
          };
          element.tray = true;
          telegram.tray = true;
          slack = { };
          chrome = { };
        };
      };
      net = {
        role = "browser";
        module = ./net.nix;
        index = 5;
        short = "net";
        label = "untrusted";
        storeGroup = "desktop";
        autostart = true;
        memory = 3072;
        memoryMax = 6144;
        vcpu = 4;
        home.size = 10000;
        apps = {
          zen = { };
          firefox.install = false;
        };
      };
      coding = {
        role = "dev";
        module = ./coding.nix;
        storeGroup = null;
        memory = 4096;
        memoryMax = 8192;
        vcpu = 4;
        home.size = 70000;
        apps = {
          postman = { };
          dbeaver = { };
          firefox = { };
        };
        index = 6;
        short = "cc";
        label = "dev";
        autostart = true;
        githubAgent = true;
        dbus = true;
        # kali tests its apps over the lab bridge (vm-lab attach)
        labTarget = true;
      };
      # Windows apps (Bottles, no gaming); internet, but no session bus and
      # no GitHub agent
      win = {
        role = "windows";
        module = ./win.nix;
        memory = 2048;
        memoryMax = 6144;
        vcpu = 4;
        home.size = 40000;
        apps.bottles.install = false;
        index = 7;
        short = "w";
        label = "untrusted";
        storeGroup = "prop";
        githubAgent = false;
        dbus = false;
      };
      office = {
        role = "desktop";
        module = ./office.nix;
        index = 9;
        short = "o";
        label = "personal";
        storeGroup = "desktop";
        uplink = null;
        memory = 2048;
        memoryMax = 6144;
        vcpu = 4;
        home.size = 20000;
        apps = {
          libreoffice = { };
          gimp = { };
          inkscape = { };
          vlc = { };
          pinta = { };
          pdfarranger = { };
        };
      };
      vault = {
        role = "desktop";
        index = 10;
        short = "v";
        label = "vault";
        storeGroup = "desktop";
        uplink = null;
        memory = 1024;
        memoryMax = 2048;
        vcpu = 1;
        home.size = 30000;
        apps.keepassxc = { };
        clipboard = "ask";
        copy.incoming = "warn";
      };
      irc = {
        role = "terminal";
        module = ./irc.nix;
        index = 11;
        short = "i";
        label = "personal";
        storeGroup = "desktop";
        autostart = true;
        uplink = null;
        memory = 2048;
        home.size = 512;
      };
      # NoX infrastructure (nox.infra): the key dom0 logs in to the builder with
      builder.hostSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINX+ZshJR9vhy9Fq1J6VteXQASQhNEzFtQ1bV1L+j1eY builder-vm";
      # the config the builder builds (dom0-update)
      builder.module.nox.builder.repoUrl = "https://github.com/23b00t/nixos";
      # Xen HVM with the dGPU (PCI passthrough); input and Bluetooth via
      # USB/IP from sys-usb (`vm-usb attach <device> steam`)
      steam = {
        role = "gaming";
        module = ./steam.nix;
        memory = 16384;
        vcpu = 10;
        home.size = 220000;
        enable = host == "xmg";
        index = 12;
        short = "s";
        label = "untrusted";
        # Games come back from Steam; its images only in a full backup
        backup = false;
        dbus = false;
      };
      # dGPU passthrough like steam; not on Xen yet
      # gpu = true: own desktop on the dGPU (mode a); false: windows over wprs
      # (mode b), the editor in software with the Compatibility renderer
      # (vms/godot.nix)
      godot = rec {
        role = "dev";
        module = ./godot.nix;
        gpu = true;
        storeGroup = null;
        memory = 16384;
        memoryMax = null;
        vcpu = 6;
        home.size = 20000;
        enable = false;
        index = 13;
        short = "g";
        label = "dev";
        githubAgent = true;
        apps = lib.optionalAttrs (!gpu) {
          godot = {
            # vms/godot.nix installs it
            install = false;
            name = "Godot";
            genericName = "Game Engine";
            icon = "godot";
            categories = [
              "Development"
              "IDE"
            ];
            args = [
              "--rendering-method"
              "gl_compatibility"
            ];
          };
        };
      };
      mirage = {
        role = "dev";
        module = ./mirage.nix;
        storeGroup = null;
        memory = 8192;
        memoryMax = null;
        vcpu = 4;
        home.size = 12000;
        enable = false;
        index = 14;
        short = "mi";
        label = "dev";
        githubAgent = true;
        dbus = false;
      };
      php = {
        role = "dev";
        module = ./php.nix;
        memory = 4096;
        memoryMax = 16384;
        vcpu = 2;
        home.size = 25000;
        apps = {
          # browsers for testing, no MIME types (dom0's defaults stay)
          firefox.mimeType = [ ];
          chromium = { };
        };
        enable = host == "xmg";
        index = 15;
        short = "p";
        label = "dev";
        storeGroup = "dev";
        githubAgent = true;
        dbus = false;
        # kali tests its apps over the lab bridge (vm-lab attach)
        labTarget = true;
      };
      ruby = {
        role = "dev";
        module = ./ruby.nix;
        memory = 4096;
        memoryMax = 12288;
        vcpu = 2;
        home.size = 25000;
        enable = host == "xmg";
        index = 16;
        short = "r";
        label = "dev";
        storeGroup = "dev";
        githubAgent = true;
        dbus = false;
      };
      nix = {
        role = "dev";
        module = ./nix.nix;
        storeGroup = null;
        memory = 8192;
        memoryMax = null;
        vcpu = 2;
        home.size = 10000;
        enable = false;
        index = 24;
        short = "nix";
        label = "dev";
        githubAgent = true;
        dbus = false;
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
    };

    # Image domains: guests from upstream disk images (Whonix, Kali), not NixOS and
    # not run by microvm.nix (NoX modules/xen-image-domains.nix). They have no
    # admin link and no sshd (dom0 calls their fixed rpc services); the index
    # only fills the tables of the scripts.
    images = {
      whonix-gateway = {
        index = 27;
        short = "wg";
        label = "anon";
      };
      whonix-workstation = {
        index = 28;
        short = "ww";
        label = "anon";
        apps.torbrowser = {
          name = "Tor Browser";
          genericName = "Web Browser";
          icon = "web-browser";
          categories = [
            "Network"
            "WebBrowser"
          ];
        };
      };
      # Kali from the upstream QEMU image (machines/xmg/xen.nix); uplink via
      # sys-net, second vif on the lab bridge (vm-lab) for testing labTarget VMs
      kali = {
        enable = host == "xmg";
        index = 8;
        short = "k";
        label = "untrusted";
        apps = {
          burpsuite = {
            name = "Burp Suite";
            genericName = "Web Security Testing";
            icon = "kali-burpsuite";
            categories = [
              "Network"
              "Security"
            ];
          };
          # own id: the catalog's firefox would add its MIME types
          firefox-esr = {
            name = "Firefox";
            genericName = "Web Browser";
            icon = "firefox";
            categories = [
              "Network"
              "WebBrowser"
            ];
          };
        };
      };
    };
  };
}
