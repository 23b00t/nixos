# Xen dom0 on xmg: the shared dom0 (machines/xen-dom0.nix) plus what only
# this machine needs.
{ lib, ... }:
{
  imports = [ ../xen-dom0.nix ];

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
