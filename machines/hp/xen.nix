# Xen dom0 on hp: the shared dom0 (NoX nixos/dom0/xen-dom0.nix) plus what only the
# test laptop has.
{ lib, inputs, ... }:
{
  imports = [ inputs.nox.nixosModules.xen-dom0 ];

  # v3: Tails (HVM, qemu in a Linux stubdomain): `xen-vnc tails` shows its
  # display. The domain itself is still a test config (xen-migration.md)
  services.xen-vnc.domains = [ "tails" ];

  # PVH dom0 is the target. On hp the I2C touchpad only works with a PV dom0
  # (see README "Known hardware issues"); a PV specialisation doubled the
  # eval memory, so it was removed again.

  # hp evaluates and builds in dom0 (no builder): with 8 GB the eval
  # (4-5 GB) pushed niri out of the page cache and typing lagged
  # (2026-10-16). 32 GB host, few VMs
  virtualisation.xen.dom0Resources.memory = lib.mkForce 12288;

  # Only the VMs switched to Xen can run; KVM-based ones would fail on start
  microvm.autostart = lib.mkForce [
    "sys-net"
    "sys-firewall"
    "sys-usb"
    "vault"
    "nvim"
    "coding"
    "chat"
  ];
}
