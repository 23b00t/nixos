{ pkgs, ... }:
let
  libvirtBridgeNetworks = [
    {
      name = "default";
      bridge = "virbr0";
    }
    {
      name = "Whonix-External";
      bridge = "virbr1";
    }
  ];

  mkNetworkXml =
    { name, bridge }:
    pkgs.writeText "libvirt-network-${bridge}.xml" ''
      <network>
        <name>${name}</name>
        <forward mode='bridge'/>
        <bridge name='${bridge}'/>
      </network>
    '';

  applyBridgeNetworks = pkgs.writeShellScript "apply-libvirt-bridge-networks" ''
    set -euo pipefail

    ensure_bridge_network() {
      local name="$1"
      local bridge="$2"
      local xml="$3"
      local current

      current="$(${pkgs.libvirt}/bin/virsh net-dumpxml "$name" 2>/dev/null || true)"

      if printf '%s' "$current" | grep -Fq "<forward mode='bridge'/>" \
        && printf '%s' "$current" | grep -Fq "<bridge name='${bridge}'"; then
        ${pkgs.libvirt}/bin/virsh net-autostart "$name" >/dev/null 2>&1 || true
        if ! ${pkgs.libvirt}/bin/virsh net-info "$name" 2>/dev/null | grep -Eq 'Active:\s+yes'; then
          ${pkgs.libvirt}/bin/virsh net-start "$name" >/dev/null 2>&1 || true
        fi
        return 0
      fi

      ${pkgs.libvirt}/bin/virsh net-destroy "$name" >/dev/null 2>&1 || true
      ${pkgs.libvirt}/bin/virsh net-undefine "$name" >/dev/null 2>&1 || true
      ${pkgs.libvirt}/bin/virsh net-define "$xml"
      ${pkgs.libvirt}/bin/virsh net-autostart "$name"
      ${pkgs.libvirt}/bin/virsh net-start "$name"
    }

    ${builtins.concatStringsSep "\n" (
      map (
        network:
        "ensure_bridge_network '${network.name}' '${network.bridge}' '${mkNetworkXml network}'"
      ) libvirtBridgeNetworks
    )}
  '';
in
{
  systemd.services.libvirt-bridge-networks = {
    description = "Ensure bridge-backed libvirt networks for sys-net mediated zones";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "libvirtd.service"
      "systemd-networkd.service"
    ];
    after = [
      "libvirtd.service"
      "systemd-networkd.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = applyBridgeNetworks;
      RemainAfterExit = true;
    };
    restartIfChanged = false;
    stopIfChanged = false;
  };
}
