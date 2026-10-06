{ pkgs, ... }:
{
  imports = [
    ../modules/net-config.nix
    ../modules/yazi-config.nix
    ../modules/ide.nix
    ../modules/zsh.nix
    ../modules/zellij.nix
    ../modules/common-config.nix
  ];

  networking.hostName = "nvim-vm";

  microvm = {
    
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 10000;
      }
    ];
    shares = [
      {
        proto = "virtiofs";
        tag = "host-home";
        source = "/home/nx";
        mountPoint = "/mnt/host";
      }
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    # Boots with 2048 MB, the RAM balancer grows it up to 4096 MB
    mem = 4096;
    balloon = true;
    initialBalloonMem = 2048;
    vcpu = 1;
  };

  environment.systemPackages = with pkgs; [
    lua-language-server
    lua51Packages.lua
    lua51Packages.luarocks
    nixfmt
    nil
    nixdoc
    deadnix
    claude-code
  ];

  services.net-config = {
    enable = true;
    index = 1;
    mac = "00:00:00:00:00:01";
  };

  services.common-config = {
    enable = true;
  };

  services.ide = {
    enable = true;
    githubAgent.enable = true;
    lazyvimRepo = "git@github.com:23b00t/lazyvim.git";
  };

  services.zellij-env = {
    enable = true;
    tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./tabs.kdl;
    };
  };

  services.zsh-env = {
    enable = true;
    ohMyPoshTheme = "1_shell.omp.json";

    extraAliases = {
      edit = "sudo -e";
    };
  };

  system.stateVersion = "26.05";
}
