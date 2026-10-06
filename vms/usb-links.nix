# USB from sys-usb to other VMs (v2.6), derived from the registry USB
# inventory. Used by sys-usb (vms/sys-usb), the consumer VMs
# (vms/modules/usbip-client.nix) and dom0 (modules/xen-usb.nix).
#
# - Devices owned by `host`: input devices, forwarded to dom0 by the input proxy
# - Devices owned by `sys-usb`: stay there
# - Devices owned by another VM: exported by usbipd in sys-usb and attached by
#   that VM over the USB/IP link (bridge `vm-usbip` in sys-usb, 10.2.0.0/24)
{ lib, vmRegistry }:
let
  devices = vmRegistry.hardware.usb.devices;
  owner = device: device.defaultOwner or null;

  exported = builtins.filter (
    d:
    !builtins.elem (owner d) [
      null
      "host"
      "sys-usb"
    ]
  ) devices;

  # Last octet of the VM's admin IP, also used on the USB/IP link
  indexOf = name: lib.toInt (lib.last (lib.splitString "." vmRegistry.byName.${name}.ip));
  hex = i: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString i));
in
rec {
  domain = "sys-usb-vm";
  # sys-usb's admin address, used by dom0 to reach it
  adminAddress = vmRegistry.byName.sys-usb.ip;
  bridge = "vm-usbip";
  serverAddress = "10.2.0.254";
  prefixLength = 24;
  port = 3240;

  inherit exported;
  inputDevices = builtins.filter (d: owner d == "host") devices;

  # VMs (present in the registry) that get USB/IP devices
  consumers = lib.unique (builtins.filter (name: vmRegistry.byName ? ${name}) (map owner exported));

  devicesFor = name: builtins.filter (d: owner d == name) exported;
  addressOf = name: "10.2.0.${toString (indexOf name)}";
  macOf = name: "00:00:00:00:02:${hex (indexOf name)}";
}
