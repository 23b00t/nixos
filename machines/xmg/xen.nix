# Xen dom0 on xmg: the shared dom0 (machines/xen-dom0.nix) plus what only
# this machine needs.
{ lib, ... }:
{
  imports = [ ../xen-dom0.nix ];

  # hp and xmg share the branch `hp` (one branch, two machines)
  services.dom0-update.branch = "hp";

  # sys-usb owns the only USB controller (00:14.0): USB keyboard and mice only
  # reach dom0 over the input proxy once it runs (the internal keyboard and
  # touchpad are not on USB). irc stays off until the Whonix-Gateway image
  # (its only uplink) is set up on this machine.
  microvm.autostart = lib.mkForce [
    "sys-net"
    "sys-usb"
    "nvim"
    "chat"
    "net"
    "coding"
  ];
}
