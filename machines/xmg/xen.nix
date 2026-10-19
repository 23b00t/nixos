# Xen dom0 on xmg: the shared dom0 (machines/xen-dom0.nix) plus what only
# this machine needs.
{
  config,
  lib,
  pkgs,
  vmRegistry,
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

  virtualisation.xen.boot.params = [
    # nixpkgs writes `,max:` only if maxMemory differs from memory; without
    # it the PV dom0 kernel reserves page structures for all 64 GB of the
    # host (Linux saw 4.7 of 6 GB, 2026-10-19). Xen keeps the size from the
    # other dom0_mem and takes only the max from this one
    "dom0_mem=max:6144M"
    # Intel HWP: the CPU picks clock and turbo itself within the limits of
    # the hardware profile (Fn key). acpi-cpufreq/ondemand capped it at
    # 2.2 GHz without turbo and ran idle cores at 800 MHz (2026-10-19)
    "cpufreq=hwp"
  ];

  systemd.services."microvm@steam" = lib.mkIf (config.microvm.vms ? steam) {
    serviceConfig = {
      ExecStartPre = [ steamPoolUp ];
      ExecStopPost = [ steamPoolDown ];
    };
  };

  # sys-usb owns the only USB controller (00:14.0): USB keyboard and mice only
  # reach dom0 over the input proxy once it runs (the internal keyboard and
  # touchpad are not on USB). irc's only uplink is the Whonix-Gateway, which
  # starts at boot as well.
  microvm.autostart = lib.mkForce [
    "sys-net"
    "sys-firewall"
    "sys-usb"
    "nvim"
    "chat"
    "net"
    "coding"
    "irc"
  ];
  services = {
    # hp and xmg share the branch `hp` (one branch, two machines)
    dom0-update.branch = "hp";

    xen-image-domains.domains = {
      whonix-gateway.autostart = true;

      # Kali from the upstream QEMU image (README "Kali (from scratch)"):
      # pvgrub2 boots Kali's kernel, apps over wprs (`vm-run k burpsuite`),
      # updates with apt in the guest (update-all). First vif: uplink on
      # sys-net (10.1.0.8), second vif: lab bridge vm-lab (10.5.0.8) to the
      # labTarget VMs (`vm-lab attach php`). The addresses are NetworkManager
      # profiles in the guest, matched by MAC (README).
      kali = {
        image = "/home/nx/vm-images/kali/kali.raw";
        # Check with `sfdisk -l kali.raw` before the first setup
        rootPartition = 1;
        memory = 6144;
        vcpus = 4;
        vifs = [
          {
            mac = "00:00:00:00:01:08";
            # Internet behind sys-firewall (static 10.6.0.8/24 via 10.6.0.254 in kali)
            bridge = "vm-fw";
            backend = "sys-firewall-vm";
          }
          {
            mac = "00:00:00:00:03:08";
            bridge = "vm-lab";
            backend = "sys-firewall-vm";
          }
        ];
        wprs = true;
      };
    };

    # Lab bridge for kali: `vm-lab attach|detach <vm>`, `vm-lab status`
    xen-lab.enable = true;
  };

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
