{ pkgs, ... }:
{
  systemd.user.services.wprsd = {
    description = "wprsd instance";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      Environment = [
        "PATH=/run/current-system/sw/bin"
        "RUST_BACKTRACE=1"
      ];
      ExecStart = "/run/current-system/sw/bin/wprsd";
    };
    wantedBy = [ "default.target" ];
  };

  environment.systemPackages = [
    pkgs.wprs
    pkgs.xwayland
  ];
}
