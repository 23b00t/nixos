{ inputs }:
let
  mkVm = name: {
    module = ./. + "/${name}";
    specialArgs = { };
    packages = { pkgs, ... }: { };
  };
in
{
  nvim = mkVm "nvim";
  chat = mkVm "chat";
  music = mkVm "music";
  net = (mkVm "net") // {
    specialArgs = {
      inherit (inputs) zen-browser;
    };
  };
  # wine = mkVm "wine";
  # kali = mkVm "kali";
  office = mkVm "office";
  vault = mkVm "vault";
  irc = mkVm "irc";
  sys-usb = mkVm "sys-usb";
  sys-net = mkVm "sys-net";
  coding = mkVm "coding";
  # create-vm: definitions
}
