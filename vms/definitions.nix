{ inputs }:
let
  mkVm = name: {
    module = ./. + "/${name}";
    specialArgs = { };
    packages = { pkgs, ... }: { };
  };
  # Infrastructure VMs come from NoX
  mkNoxVm = name: (mkVm name) // { module = inputs.nox.lib.vms + "/${name}"; };
in
{
  win = mkVm "win";
  steam = mkVm "steam";
  sys-usb = mkNoxVm "sys-usb";
  sys-net = mkNoxVm "sys-net";
  builder = mkNoxVm "builder";
  sys-print = mkNoxVm "sys-print";
  sys-vpn = mkNoxVm "sys-vpn";
  disp = mkNoxVm "disp";
  disp-backup = mkNoxVm "disp-backup";
  sys-firewall = mkNoxVm "sys-firewall";
}
