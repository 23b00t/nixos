# Xen dom0, shared by all machines (hp, xmg), on top of
# common-configuration.nix. Machine specifics come from the registry view
# (`hardware`, `hostProfile`) and machines/<name>/xen.nix.
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
  # NIC drivers blacklisted in dom0 (registry hostProfile), loaded again by
  # sys-net-rescue
  nicDrivers =
    (vmRegistry.hostProfile.blockedHostDrivers.nic or [ ])
    ++ (vmRegistry.hostProfile.blockedHostDrivers.wifi or [ ]);
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
    ${lib.concatMapStringsSep "\n" (m: "sudo ${pkgs.kmod}/bin/modprobe ${m}") nicDrivers}
    echo "WLAN is back in dom0, NetworkManager reconnects as before."
    echo "Start sys-net again later with: sudo systemctl start microvm@sys-net"
  '';

  # Full system update, step 2 (step 1: `flake-bump` in nvim pushes new
  # inputs): dom0 from the builder, then the Debian systems inside the
  # Whonix images, which dom0-update does not touch (it only renews their
  # store disk). Domains that were off are started and stopped again.
  updateAll = pkgs.writeShellScriptBin "update-all" ''
    set -euo pipefail

    usage() {
      cat <<EOF >&2
    Usage: update-all [--switch] [--machine <name>] [--branch <branch>]

    Full update: dom0 from the builder (dom0-update with the same arguments;
    --switch activates right away), then the Whonix-Gateway and -Workstation
    (apt over Tor). New flake inputs first with flake-bump in nvim. Only
    rebuild dom0: dom0-update.
    EOF
      exit 1
    }
    case "''${1:-}" in
      -h | --help) usage ;;
    esac

    # One password prompt for the whole run (dom0-update reuses it)
    if [ -t 0 ]; then
      sudo -v
      while sleep 60; do sudo -n -v 2>/dev/null || exit; done &
      keepalive=$!
    fi

    started=()
    cleanup() {
      local i
      for ((i = ''${#started[@]} - 1; i >= 0; i--)); do
        echo "update-all: stopping ''${started[i]} again" >&2
        sudo systemctl stop "xen-image@''${started[i]}" || true
      done
      [ -z "''${keepalive:-}" ] || kill "$keepalive" 2>/dev/null || true
    }
    trap cleanup EXIT

    dom0-update "$@"

    # Starts the domain if it is off (the Gateway waits for sys-net's uplink)
    ensure_running() {
      if ! systemctl is-active --quiet "xen-image@$1"; then
        echo "update-all: starting $1" >&2
        sudo systemctl start "xen-image@$1"
        started+=("$1")
      fi
    }

    # sdwdate syncs only over working Tor; the Workstation's firewall stays
    # closed until then
    wait_tor() {
      echo "update-all: waiting for Tor in $1 (sdwdate)" >&2
      for _ in $(seq 60); do
        ssh -o ConnectTimeout=5 "$1-vm" test -e /run/sdwdate/first_success 2>/dev/null && return 0
        sleep 5
      done
      echo "update-all: no Tor in $1 after 5 min" >&2
      return 1
    }

    # A running domain with a newer kernel on disk: offer a restart (pvgrub
    # boots the newest one); domains we started are stopped anyway
    offer_restart() {
      local newest running answer
      case " ''${started[*]} " in *" $1 "*) return 0 ;; esac
      newest="$(ssh "$1-vm" 'ls /boot/vmlinuz-* | sort -V | tail -n 1')"
      running="$(ssh "$1-vm" 'echo "/boot/vmlinuz-$(uname -r)"')"
      [ "$newest" != "$running" ] || return 0
      read -r -p "update-all: new kernel in $1, restart it now? [y/N] " answer
      case "$answer" in
        y | Y) sudo systemctl restart "xen-image@$1" ;;
      esac
    }

    ensure_running whonix-gateway
    wait_tor whonix-gateway
    echo "update-all: updating the Whonix-Gateway" >&2
    ssh -t whonix-gateway-vm sudo apt-get-update-plus dist-upgrade

    ensure_running whonix-workstation
    wait_tor whonix-workstation
    # sudo is blocked for `user` in the Workstation (user/sysmaint split);
    # upgrade-nonroot is Whonix' update path for the normal session
    echo "update-all: updating the Whonix-Workstation" >&2
    ssh -t whonix-workstation-vm upgrade-nonroot

    offer_restart whonix-workstation
    offer_restart whonix-gateway
    echo "update-all: done" >&2
  '';
in
{
  imports = [
    ../modules/xen-memory.nix
    ../modules/dom0-update.nix
    ../modules/xen-usb.nix
    ../modules/xen-links.nix
    ../modules/xen-image-domains.nix
    ../modules/xen-vnc.nix
    inputs.nox.nixosModules.relay
    inputs.nox.nixosModules.rpc
  ];

  virtualisation.xen = {
    enable = true;
    # Test phase: guest consoles are logged to /var/log/xen/console/
    trace = true;
    boot = {
      builderVerbosity = "info"; # report which Xen boot entries were created
      # PVH is the default; registry hostProfile.dom0Pv = true boots a PV dom0
      params = [ (if vmRegistry.hostProfile.dom0Pv or false then "dom0=pv" else "dom0=pvh") ];
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
    # wprsc socket is /run/nox-relay/<vm>-wprs.sock; apps get dom0's pulse),
    # SSH to the guests (stage B: /run/nox-relay/<vm>-ssh.sock).
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
            listen =
              lib.optionalAttrs wprs {
                wprs = {
                  path = "/run/nox-relay/${name}-wprs.sock";
                  owner = "1000:100";
                };
              }
              // lib.optionalAttrs guest.config.config.services.openssh.enable {
                # dom0's ssh to the guest (ProxyCommand in home/ssh.nix)
                ssh = {
                  path = "/run/nox-relay/${name}-ssh.sock";
                  owner = "1000:100";
                };
              };
          }
        ) (lib.filterAttrs (_: vm: vm.config.config.microvm.hypervisor == "xen") config.microvm.vms)
      );
    };
  };

  # Stage C: RPC between app VMs (NoX nox-rpc), mediated by dom0. Copying
  # (`vm-copy <vm> <files>` in a VM) always asks (notification with buttons).
  # Guest side: vms/modules/vchan-relay.nix
  services.nox-rpc.host = {
    enable = true;
    guests = builtins.filter (
      vm:
      !builtins.elem vm [
        "sys-net"
        "sys-usb"
        "builder"
      ]
      && config.microvm.vms.${vm}.config.config.microvm.hypervisor == "xen"
    ) (builtins.attrNames config.microvm.vms);
    policy = [
      # sys-print (C2) holds no user data: no files in or out, only print jobs
      {
        service = "copy";
        source = "sys-print";
        action = "deny";
      }
      {
        service = "copy";
        target = "sys-print";
        action = "deny";
      }
      {
        service = "print";
        target = "sys-print";
        action = "ask";
      }
      {
        service = "copy";
        action = "ask";
      }
    ];
  };

  # v3: Whonix-Gateway from the upstream image (PVH, pvgrub2), not NixOS.
  # Outside: eth0 on sys-net's `vm-whx-ext` (10.0.2.15 via 10.0.2.2, as in the
  # image). Inside: it serves the vifs of irc/workstation itself on the bridge
  # `eth1` (Whonix' internal interface), so sys-net only sees Tor traffic.
  # Terminal only: `vm-run -c wg …` (SSH over vchan). Image setup once with
  # `xen-image-setup whonix-gateway` (xen-migration.md).
  services.xen-image-domains.domains.whonix-gateway = {
    # Test phase: the converted download; later /var/lib/xen-images
    image = "/home/nx/vm-images/whonix/whonix-gateway.raw";
    rootPartition = 3;
    memory = 1024;
    vcpus = 2;
    vifs = [
      {
        mac = "00:00:00:00:01:1b";
        bridge = "vm-whx-ext";
        waitForUplink = true;
      }
    ];
    ifupdownHotplug = [ "eth0" ];
    driverDomain = true;
    internalBridge = "eth1";
    authorizedKeys = map (d: d.hostSSHKey) (
      builtins.filter (d: d.name == "whonix-gateway") vmRegistry.imageDomains
    );
  };

  # v3: Whonix-Workstation (LXQt image), only network: the gateway's eth1.
  # Apps over wprs (`vm-run ww torbrowser`), audio over dom0's pulse.
  services.xen-image-domains.domains.whonix-workstation = {
    image = "/home/nx/vm-images/whonix/whonix-workstation.raw";
    rootPartition = 3;
    memory = 2048;
    vcpus = 2;
    vifs = [
      {
        mac = "00:00:00:00:01:1c";
        bridge = "eth1";
        backend = "whonix-gateway-vm";
        backendAddress = "/run/nox-relay/whonix-gateway-ssh.sock";
      }
    ];
    ifupdownHotplug = [ "eth0" ];
    wprs = true;
    authorizedKeys = map (d: d.hostSSHKey) (
      builtins.filter (d: d.name == "whonix-workstation") vmRegistry.imageDomains
    );
  };

  # v2.5: the WLAN card belongs to sys-net (registry `hardware.pci`, driver
  # blacklisted in dom0). `sys-net-rescue` hands it back in an emergency.
  environment.systemPackages = [
    sysNetRescue
    updateAll
  ];

  # nox-relay (root) creates the wprs sockets for dom0's wprsc here
  systemd.tmpfiles.rules = [ "d /run/nox-relay 0755 root root -" ];

  # Xen creates vifs as vif<domid>.<n> before renaming them to vm<N>
  networking.networkmanager.unmanaged = [ "interface-name:vif*" ];

  systemd = {
    services = {
      # The microvm@ services manage the domains. xendomains (no /etc/xen/auto)
      # falls back to `xl shutdown --all --wait` in parallel and hangs until
      # systemd's stop timeout (90 s) on every dom0 shutdown.
      xendomains.enable = false;
      # oxenstored ignores SIGTERM: every shutdown waited 90 s for the
      # SIGKILL. Its state only lives in RAM, nothing to save on the way down
      xenstored.serviceConfig.TimeoutStopSec = "5s";
      # A stopped VM can stay behind as a shut-down domain (state "s", its
      # qemu already gone) that still holds its PCI devices: pci-setup then
      # fails with "failed to quarantine" and the VM only started again after
      # a reboot (sys-net, 2026-10-10/11). On `systemctl restart` pci-setup
      # starts in the same second the old domain begins shutting down, so
      # wait for it to go away and destroy it if it doesn't. The VM itself
      # only starts after pci-setup, so no running domain is hit here.
      "microvm-pci-devices@".serviceConfig.ExecStartPre = [
        "${pkgs.writeShellScript "destroy-leftover-domain" ''
          xl=${config.virtualisation.xen.package}/bin/xl
          dom="$1-vm"
          for _ in $(seq 30); do
            $xl domid "$dom" >/dev/null 2>&1 || exit 0
            sleep 1
          done
          echo "destroying leftover domain $dom: $($xl list "$dom" 2>/dev/null | tail -n 1)"
          $xl destroy "$dom" || true
        ''} %i"
      ];
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
