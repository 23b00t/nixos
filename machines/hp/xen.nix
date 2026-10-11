# Xen dom0 on hp: the shared dom0 (machines/xen-dom0.nix) plus what only the
# test laptop has.
{ lib, ... }:
{
  imports = [ ../xen-dom0.nix ];

  # v3: Tails (HVM, qemu in a Linux stubdomain): `xen-vnc tails` shows its
  # display. The domain itself is still a test config (xen-migration.md)
  services.xen-vnc.domains = [ "tails" ];

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
}
