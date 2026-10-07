# Keeps the vifs served by driver domains connected (v2.8.1):
# - uplinks (backend sys-net, from each VM's net-config) and USB/IP links
#   (backend sys-usb, vms/usb-links.nix)
# - a vif is (re)attached when it is missing, hangs on an old backend domid
#   (driver domain restarted), reports hotplug errors, or is not connected
#   for `graceRounds` rounds
# - USB/IP: when a consumer VM goes away or restarts, its devices are released
#   in sys-usb, because the usbip-host stub never notices a vanished client
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
  sshOpts = "-n -o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR";

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
        release = "-";
      }
    ) config.microvm.vms
  );

  usbipLinks = map (vm: {
    domain = "${vm}-vm";
    mac = usbLinks.macOf vm;
    inherit (usbLinks) bridge;
    backend = usbLinks.domain;
    backendAddress = usbLinks.adminAddress;
    # vendor:product of the VM's devices, released in sys-usb on a restart
    release = lib.concatMapStringsSep "," (d: "${d.vendorId}:${d.productId}") (usbLinks.devicesFor vm);
  }) (builtins.filter (vm: config.microvm.vms ? ${vm}) usbLinks.consumers);

  # "domain mac bridge backend backendAddress release" per line
  linkTable = pkgs.writeText "xen-links" (
    lib.concatMapStrings (
      l: "${l.domain} ${l.mac} ${l.bridge} ${l.backend} ${l.backendAddress} ${l.release}\n"
    ) (uplinks ++ usbipLinks)
  );

  xenLinks = pkgs.writeShellScript "xen-links" ''
    PATH=${
      lib.makeBinPath [
        xen
        pkgs.coreutils
        pkgs.gawk
        pkgs.bash
        pkgs.openssh
        pkgs.util-linux
      ]
    }
    declare -A lastdom notconnected

    # Release a consumer's USB/IP devices in sys-usb (as the dom0 user, whose
    # SSH setup reaches sys-usb)
    release() {
      runuser -u ${cfg.user} -- ssh ${sshOpts} "$2" sudo usbip-release "''${1//,/ }"
    }

    while true; do
      while read -r dom mac bridge backend address devices <&3; do
        key="$dom/$mac"
        domid="$(xl domid "$dom" 2>/dev/null)" || domid=""

        if [ "$devices" != - ] && [ -n "''${lastdom[$key]:-}" ] \
          && [ "''${lastdom[$key]}" != "$domid" ]; then
          echo "$dom: domain gone or restarted, releasing its USB/IP devices"
          # Keep the old domid on failure, so the next round retries
          release "$devices" "$address" && lastdom[$key]="$domid"
        else
          lastdom[$key]="$domid"
        fi

        [ -n "$domid" ] || continue
        # The backend must be up (its bridge exists only once its network is
        # configured), otherwise the hotplug script there fails
        bedomid="$(xl domid "$backend" 2>/dev/null)" || continue
        timeout 1 bash -c "</dev/tcp/$address/22" 2>/dev/null || continue

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

    user = lib.mkOption {
      type = lib.types.str;
      default = "nx";
      description = "dom0 user whose SSH setup reaches sys-usb (to release USB/IP devices).";
    };

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
