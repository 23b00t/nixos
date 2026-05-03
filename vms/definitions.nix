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
      zen-browser = inputs.zen-browser;
    };
  };
  wine = mkVm "wine";
  kali = mkVm "kali";
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
  sys-usb = mkVm "sys-usb";
  sys-net = mkVm "sys-net";
  nix = mkVm "nix";
  coding = mkVm "coding";
  test = mkVm "test";
}
