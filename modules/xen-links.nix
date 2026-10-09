# Keeps the vifs served by driver domains connected (v2.8.1):
# - uplinks (backend sys-net, from each VM's net-config) and USB/IP links
#   (backend sys-usb, vms/usb-links.nix)
# - a vif is (re)attached when it is missing, hangs on an old backend domid
#   (driver domain restarted), reports hotplug errors, or is not connected
#   for `graceRounds` rounds
# - USB/IP links go to every Xen target VM (vms/usb-links.nix); which devices
#   a VM gets is up to vm-usb (modules/xen-usb.nix)
{
  lib,
  pkgs,
  config,
  vmRegistry,
  ...
}:
let
  cfg = config.services.xen-links;
  usbLinks = import ../vms/usb-links.nix { inherit lib vmRegistry; };
  xen = config.virtualisation.xen.package;

  uplinks = lib.concatLists (
    lib.mapAttrsToList (
      _: vm:
      let
        guest = vm.config.config;
        net = guest.services.net-config or { };
      in
      lib.optional (guest.microvm.hypervisor == "xen" && (net.enable or false) && net.uplink.enable) {
        domain = guest.networking.hostName;
        inherit (net.uplink)
          mac
          bridge
          backend
          backendAddress
          ;
      }
    ) config.microvm.vms
  );

  usbipLinks =
    map
      (vm: {
        domain = "${vm}-vm";
        mac = usbLinks.macOf vm;
        inherit (usbLinks) bridge;
        backend = usbLinks.domain;
        # Without an admin link (stage B2) sys-usb is checked through the relay
        backendAddress =
          config.services.nox-relay.host.guests.sys-usb.listen.ssh.path or usbLinks.adminAddress;
      })
      (
        builtins.filter (
          vm: usbLinks.isTarget vm && config.microvm.vms.${vm}.config.config.microvm.hypervisor == "xen"
        ) (builtins.attrNames config.microvm.vms)
      );

  # "domain mac bridge backend backendAddress" per line
  linkTable = pkgs.writeText "xen-links" (
    lib.concatMapStrings (l: "${l.domain} ${l.mac} ${l.bridge} ${l.backend} ${l.backendAddress}\n") (
      uplinks ++ usbipLinks
    )
  );

  xenLinks = pkgs.writeShellScript "xen-links" ''
    PATH=${
      lib.makeBinPath [
        xen
        pkgs.coreutils
        pkgs.gawk
        pkgs.bash
        pkgs.socat
      ]
    }
    declare -A notconnected

    # Is the backend's sshd reachable? An IP over the admin network, or a
    # nox-relay socket (stage B2): then the SSH banner comes back over vchan
    reachable() {
      case "$1" in
        /*) [ "$(timeout 3 socat -t 2 - "UNIX-CONNECT:$1" </dev/null 2>/dev/null | head -c 4)" = SSH- ] ;;
        *) timeout 1 bash -c "</dev/tcp/$1/22" 2>/dev/null ;;
      esac
    }

    while true; do
      while read -r dom mac bridge backend address <&3; do
        key="$dom/$mac"
        domid="$(xl domid "$dom" 2>/dev/null)" || domid=""

        [ -n "$domid" ] || continue
        # The backend must be up (its bridge exists only once its network is
        # configured), otherwise the hotplug script there fails
        bedomid="$(xl domid "$backend" 2>/dev/null)" || continue
        reachable "$address" || continue

        # Idx BE Mac handle state ...; state 4 = connected
        idx="" be="" state="" hotplug=""
        read -r idx be state < <(xl network-list "$dom" 2>/dev/null </dev/null \
          | awk -v mac="$mac" '$3 == mac { print $1, $2, $5 }')
        if [ -n "$idx" ]; then
          # The backend's hotplug script (vif-bridge there) reports here
          hotplug="$(xenstore-read "/local/domain/$be/backend/vif/$domid/$idx/hotplug-status" 2>/dev/null)"
          if [ "$state" = 4 ]; then
            notconnected[$key]=0
          else
            notconnected[$key]=$(( ''${notconnected[$key]:-0} + 1 ))
          fi
          if [ "$be" != "$bedomid" ] || [ "$hotplug" = error ] \
            || [ "''${notconnected[$key]}" -ge ${toString cfg.graceRounds} ]; then
            echo "$dom: detaching stale vif $mac (backend $be, state $state, hotplug $hotplug)"
            timeout 30 xl network-detach "$dom" "$idx" </dev/null || true
            idx=""
          fi
        fi
        if [ -z "$idx" ]; then
          echo "$dom: attaching vif $mac (bridge $bridge, backend $backend)"
          timeout 30 xl network-attach "$dom" mac="$mac" bridge="$bridge" backend="$backend" </dev/null || true
          notconnected[$key]=0
        fi
      done 3< ${linkTable}
      sleep 5
    done
  '';
in
{
  options.services.xen-links = {
    enable = lib.mkEnableOption "keeping uplink and USB/IP vifs connected to their driver domains";

    graceRounds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 12;
      description = "Rounds (5 s each) a vif may stay unconnected before it is re-attached (guest boot).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.xen-links = {
      description = "Keep uplink and USB/IP vifs connected to their driver domains";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = xenLinks;
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
