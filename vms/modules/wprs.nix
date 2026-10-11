{ pkgs, ... }:
{
  # Held modifiers follow the compositor (stuck Super, xen-migration.md);
  # same patch as dom0 (machines/common-configuration.nix)
  nixpkgs.overlays = [
    (final: prev: {
      wprs = prev.wprs.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../modules/wprs-modifier-sync.patch ];
      });
    })
  ];

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
