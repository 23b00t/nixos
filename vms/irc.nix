# irc: IRC (tiny) and Matrix (iamb) in the terminal, over Tor only.
{ pkgs, ... }:
{
  # v3: the only network is the uplink to the Whonix-Gateway (backend of the
  # vif, bridge eth1 there), never sys-net.
  services.net-config = {
    dns = [ "10.152.152.10" ];
    uplink = {
      enable = true;
      address4 = "10.152.152.21/18";
      gateway4 = "10.152.152.10";
      backend = "whonix-gateway-vm";
      bridge = "eth1";
    };
  };

  services.zellij-env.tabsKdlFile = builtins.path {
    name = "tabs.kdl";
    path = ./irc-tabs.kdl;
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
}
