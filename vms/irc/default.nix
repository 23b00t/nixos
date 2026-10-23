{ pkgs, inputs, ... }:
let
  index = 11;
in
{
  imports = [
    (inputs.nox.lib.vms + "/modules/net-config.nix")
    (inputs.nox.lib.vms + "/modules/common-config.nix")
    (inputs.nox.lib.vms + "/modules/zellij.nix")
  ];

  networking.hostName = "irc-vm";

  # v3: the only network is the uplink to the Whonix-Gateway (backend of the
  # vif, bridge eth1 there), never sys-net.
  services.net-config = {
    enable = true;
    inherit index;
    mac = "00:00:00:00:00:0b";
    dns = [ "10.152.152.10" ];
    uplink = {
      enable = true;
      address4 = "10.152.152.21/18";
      gateway4 = "10.152.152.10";
      backend = "whonix-gateway-vm";
      bridge = "eth1";
    };
  };

  microvm = {

    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 512;
      }
    ];
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    mem = 2048;
  };

  services.zellij-env = {
    enable = true;
    tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./tabs.kdl;
    };
  };

  services.common-config = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tiny" ''
      export GPG_TTY=$(tty)
      ${gnupg}/bin/gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
      exec ${tiny}/bin/tiny "$@"
    '')
    pass
    gnupg
    pinentry-curses
    proxychains-ng
    openssl
    iamb
  ];

  environment.etc."proxychains.conf".text = ''
    [ProxyList]
    socks5  10.152.152.10 9050
  '';

  system.stateVersion = "26.05";
}
