{ pkgs, ... }:
let
  index = 11;
in
{
  imports = [
    ../modules/whonix-net-config.nix
    ../modules/common-config.nix
    ../modules/zellij.nix
  ];

  microvm.interfaces = [
    {
      type = "tap";
      id = "vm${toString index}";
      mac = "02:00:00:00:00:0b";
    }
    {
      type = "tap";
      id = "vm${toString index}-tor";
      mac = "02:00:00:00:00:0c";
    }
  ];

  networking.hostName = "irc-vm";

  services.whonix-net-config = {
    enable = true;
    id = index;
  };

  microvm = {
    
    hypervisor = "cloud-hypervisor";
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
