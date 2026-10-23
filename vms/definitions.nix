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
  nvim = mkVm "nvim";
  chat = mkVm "chat";
  net = (mkVm "net") // {
    specialArgs = {
      inherit (inputs) zen-browser;
    };
  };
  win = mkVm "win";
  office = mkVm "office";
  vault = mkVm "vault";
  irc = mkVm "irc";
  steam = mkVm "steam";
  godot = mkVm "godot";
  mirage = mkVm "mirage";
  php = (mkVm "php") // {
    packages = { pkgs, ... }: import ./php/packages.nix { inherit pkgs; };
  };
  ruby = mkVm "ruby";
  sys-usb = mkNoxVm "sys-usb";
  sys-net = mkNoxVm "sys-net";
  nix = mkVm "nix";
  coding = mkVm "coding";
  builder = mkNoxVm "builder";
  sys-print = mkNoxVm "sys-print";
  sys-vpn = mkNoxVm "sys-vpn";
  disp = mkNoxVm "disp";
  disp-backup = mkNoxVm "disp-backup";
  sys-firewall = mkNoxVm "sys-firewall";
}
