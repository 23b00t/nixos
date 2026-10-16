# Xen dom0 on xmg: the shared dom0 (machines/xen-dom0.nix) plus what only
# this machine needs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  xl = "${config.virtualisation.xen.package}/bin/xl";

  # steam gets the P-cores to itself while it runs: CPUs 0-15 (8 P-cores
  # with HT) move from Pool-0 into the cpupool "steam" (vms/steam:
  # microvm.xen.pool), dom0 and the other VMs keep the E-cores 16-31. A CPU
  # Xen refuses to move (CPU 0 may have to stay in Pool-0) stays there
  steamPoolUp = pkgs.writeShellScript "steam-cpupool-up" ''
    set -u
    ${xl} cpupool-list | ${pkgs.gawk}/bin/awk '$1 == "steam" { found = 1 } END { exit !found }' ||
      ${xl} cpupool-create name=\"steam\" || exit 1
    for cpu in $(seq 0 15); do
      ${xl} cpupool-cpu-remove Pool-0 "$cpu" 2>/dev/null || {
        echo "steam-cpupool: CPU $cpu stays in Pool-0" >&2
        continue
      }
      ${xl} cpupool-cpu-add steam "$cpu" || ${xl} cpupool-cpu-add Pool-0 "$cpu"
    done
  '';
  # After the stop (the domain is gone, ExecStopPost of microvm@ in
  # machines/xen-dom0.nix runs first): everything back to Pool-0
  steamPoolDown = pkgs.writeShellScript "steam-cpupool-down" ''
    set -u
    ${xl} cpupool-list | ${pkgs.gawk}/bin/awk '$1 == "steam" { found = 1 } END { exit !found }' || exit 0
    for cpu in $(seq 0 15); do
      ${xl} cpupool-cpu-remove steam "$cpu" 2>/dev/null && ${xl} cpupool-cpu-add Pool-0 "$cpu"
    done
    ${xl} cpupool-destroy steam
  '';
in
{
  imports = [ ../xen-dom0.nix ];

  # dom0 with 6 GB (measured 2026-10-15: 2.0 GB used + 0.7 GB shared of
  # 6.8 GB). The xmg evaluates and builds in the builder VM (dom0-update),
  # not in dom0; hp keeps 8 GB (local evaluation, machines/xen-dom0.nix)
  virtualisation.xen.dom0Resources = {
    memory = lib.mkForce 6144;
    maxMemory = 6144;
  };

  systemd.services."microvm@steam" = lib.mkIf (config.microvm.vms ? steam) {
    serviceConfig = {
      ExecStartPre = [ steamPoolUp ];
      ExecStopPost = [ steamPoolDown ];
    };
  };

  # hp and xmg share the branch `hp` (one branch, two machines)
  services.dom0-update.branch = "hp";

  # sys-usb owns the only USB controller (00:14.0): USB keyboard and mice only
  # reach dom0 over the input proxy once it runs (the internal keyboard and
  # touchpad are not on USB). irc's only uplink is the Whonix-Gateway, which
  # starts at boot as well.
  microvm.autostart = lib.mkForce [
    "sys-net"
    "sys-usb"
    "nvim"
    "chat"
    "net"
    "coding"
    "irc"
  ];
  services.xen-image-domains.domains.whonix-gateway.autostart = true;

  # GSI 18 is shared by the RTL8125 (sys-net, INTx with pci=nomsi), the SMBus
  # (00:1f.4) and the dGPU's HDMI audio (02:00.1). While dom0 drivers hold
  # the line, Xen cannot unmap it from a stopped sys-net ("unmap_gsi …
  # Device or resource busy": the domain stays "---s--", sys-net only comes
  # back after a reboot), and the shared line likely cost sys-net packets
  # (2026-10-11). dom0 lets go of it: the dGPU (both functions, steam's
  # later anyway) goes to pciback at boot, the SMBus driver polls.
  boot.kernelParams = [
    "xen_pciback.hide=(0000:02:00.0)(0000:02:00.1)"
    "i2c_i801.disable_features=0x30"
  ];
  # Loaded in the initrd, so pciback claims the dGPU before snd_hda_intel
  boot.initrd.kernelModules = [ "xen_pciback" ];
}
