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
}
