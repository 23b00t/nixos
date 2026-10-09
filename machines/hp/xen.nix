# Xen dom0 test setup for hp: replaces the KVM stack (libvirt) from
# common-configuration.nix. Based on the former `xen` branch.
# MicroVMs run as Xen PVH domUs via the microvm.nix fork (hypervisor = "xen").
{
  lib,
  pkgs,
  config,
  inputs,
  vmRegistry,
  ...
}:
let
  nicPciPaths = vmRegistry.hardware.pci.devicePaths.nic or [ ];
  dom0TestAccess = vmRegistry.hostProfile.dom0TestAccess or null;

  # Emergency exit if sys-net does not come up: give the WLAN card back to dom0
  sysNetRescue = pkgs.writeShellScriptBin "sys-net-rescue" ''
    set -u
    sudo systemctl stop microvm@sys-net
    # A domain left behind (e.g. paused/shut down) would keep the card
    if sudo xl domid sys-net-vm >/dev/null 2>&1; then
      sudo xl destroy sys-net-vm || true
    fi
    ${lib.concatMapStrings (path: ''
      sudo xl pci-assignable-remove -r ${path} || true
    '') nicPciPaths}
    # Blacklisted for autoloading only; an explicit modprobe works
    sudo ${pkgs.kmod}/bin/modprobe rtw88_8821ce
    echo "WLAN is back in dom0, NetworkManager reconnects as before."
    echo "Start sys-net again later with: sudo systemctl start microvm@sys-net"
  '';
in
{
  imports = [
    ../../modules/xen-memory.nix
    ../../modules/dom0-update.nix
    ../../modules/xen-usb.nix
    ../../modules/xen-links.nix
    inputs.nox.nixosModules.relay
  ];

  virtualisation.xen = {
    enable = true;
    # Test phase: guest consoles are logged to /var/log/xen/console/
    trace = true;
    boot = {
      builderVerbosity = "info"; # report which Xen boot entries were created
      params = [ "dom0=pvh" ];
    };
    dom0Resources = {
      # 4096 is too small to evaluate this flake on dom0 (swap thrashing)
      memory = 8192;
      maxVCPUs = 4;
    };
  };

  # dom0 keeps its memory: xl must not take it to start guests. The RAM
  # balancer only moves memory between ballooning MicroVMs.
  environment.etc."xen/xl.conf".source = lib.mkForce (
    pkgs.runCommand "xl.conf" { } ''
      cat ${config.virtualisation.xen.package}/etc/xen/xl.conf > $out
      echo 'autoballoon="off"' >> $out
    ''
  );

  services = {
    xen-memory-balancer.enable = true;

    # dom0 pulls its system from the builder VM (v2.4): `dom0-update [--switch]`
    dom0-update.enable = true;

    # v2.6: both USB controllers belong to sys-usb; input devices come back via
    # the input proxy, the webcam goes to chat via USB/IP. `sys-usb-rescue`.
    xen-usb.enable = true;

    # v2.8.1: re-attaches uplink and USB/IP vifs after a driver domain or VM
    # restart, releases USB/IP devices of VMs that went away
    xen-links.enable = true;

    # v2.8.4: sockets for Xen guests over vchan (NoX nox-relay) instead of SSH
    # forwards: GitHub agent (registry `allowGitHubAgent`), filtered session
    # bus (`enableHostDbusForward`), wprs for VMs with wprsd (`vm-gui`, the
    # wprsc socket is /run/nox-relay/<vm>-wprs.sock; apps get dom0's pulse).
    # Guest side: vms/modules/vchan-relay.nix
    nox-relay.host = {
      enable = true;
      guests = lib.filterAttrs (_: g: g.serve != { } || g.listen != { }) (
        lib.mapAttrs (
          name: guest:
          let
            vm = vmRegistry.byName.${name} or { };
            wprs = guest.config.config.systemd.user.services ? wprsd;
          in
          {
            domain = "${name}-vm";
            serve =
              lib.optionalAttrs (vm.allowGitHubAgent or false) {
                github-agent = "/home/nx/.ssh/agent/github.sock";
              }
              // lib.optionalAttrs (vm.enableHostDbusForward or true) {
                dbus = "/run/user/1000/vm-session-bus.sock";
              }
              // lib.optionalAttrs wprs { pulse = "/run/user/1000/pulse/native"; };
            listen = lib.optionalAttrs wprs {
              wprs = {
                path = "/run/nox-relay/${name}-wprs.sock";
                owner = "1000:100";
              };
            };
          }
        ) (lib.filterAttrs (_: vm: vm.config.config.microvm.hypervisor == "xen") config.microvm.vms)
      );
    };
  };

  # v2.5: the WLAN card belongs to sys-net (registry `hardware.pci`, driver
  # blacklisted in dom0). `sys-net-rescue` hands it back in an emergency.
  environment.systemPackages = [ sysNetRescue ];

  # nox-relay (root) creates the wprs sockets for dom0's wprsc here
  systemd.tmpfiles.rules = [ "d /run/nox-relay 0755 root root -" ];

  # PVH dom0 is the target. On hp the I2C touchpad only works with a PV dom0
  # (see README "Known hardware issues"); a PV specialisation doubled the
  # eval memory, so it was removed again.

  # Only the VMs switched to Xen can run; KVM-based ones would fail on start
  microvm.autostart = lib.mkForce [
    "sys-net"
    "sys-usb"
    "vault"
    "nvim"
    "coding"
    "chat"
  ];

  # Xen creates vifs as vif<domid>.<n> before renaming them to vm<N>
  networking.networkmanager.unmanaged = [ "interface-name:vif*" ];

  # No KVM under Xen: no libvirt
  virtualisation.libvirtd.enable = lib.mkForce false;
  programs.virt-manager.enable = lib.mkForce false;

  systemd = {
    services = {
      # The microvm@ services manage the domains. xendomains (no /etc/xen/auto)
      # falls back to `xl shutdown --all --wait` in parallel and hangs until
      # systemd's stop timeout (90 s) on every dom0 shutdown.
      xendomains.enable = false;
      libvirt-bridge-networks.enable = false;
      retrigger-vm11-tor-udev.enable = false;
    };

    network.networks =
      # Admin network: every VM port is isolated, so VMs reach dom0 (the
      # non-isolated bridge itself) but not each other. Their internet goes
      # through the uplink served by sys-net.
      lib.genAttrs (map (i: "30-vm${toString i}") (lib.genList (i: i + 1) 50) ++ [ "31-vm-router" ]) (_: {
        bridgeConfig.Isolated = true;
      })
      // {
        # dom0: default route via sys-net in the test phase (HTTPS/DNS/NTP
        # only, see vms/sys-net); without dom0TestAccess dom0 is offline
        "32-vm-internal" = {
          # High metric: after `sys-net-rescue` the WLAN route from
          # NetworkManager (metric 600) wins over the dead sys-net
          routes = lib.mkForce (
            lib.optional (dom0TestAccess != null) {
              Destination = "0.0.0.0/0";
              Gateway = "10.0.0.253";
              Metric = 2000;
            }
          );
          networkConfig.DNS = lib.mkIf (dom0TestAccess != null) [
            "9.9.9.9"
            "149.112.112.112"
          ];
        };
      };
  };
}
