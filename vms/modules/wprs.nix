{ lib, pkgs, ... }:
let
  theme = import ../../home/desktop/theme.nix { inherit lib; };
  # No selection sync with dom0 (WPRS_NO_SELECTION_SYNC below), explicit
  # copy/paste via dom0's vm-clip
  clipboard = import ../../modules/wprs-clipboard.nix { inherit pkgs; };
in
{
  # Held modifiers follow the compositor (stuck Super, xen-migration.md);
  # same patch as dom0 (machines/common-configuration.nix); frame callbacks wait
  # while frames queue up for dom0 (back pressure, wprsd OOM during video)
  nixpkgs.overlays = [
    (final: prev: {
      wprs = prev.wprs.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../../modules/wprs-modifier-sync.patch
          ../../modules/wprs-frame-backpressure.patch
          clipboard.patch
        ];
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
        "WPRS_NO_SELECTION_SYNC=1"
      ];
      # Frame callbacks come from a wprsd timer (1/framerate - 2 ms after each
      # commit, default 60): Firefox got ~50 fps and dropped a third of a
      # 60 fps video; with 120 about 10-20 % (xmg 2026-10-18, README Known issues)
      ExecStart = "/run/current-system/sw/bin/wprsd --framerate 120";
    };
    wantedBy = [ "default.target" ];
  };

  environment.systemPackages = [
    pkgs.wprs
    pkgs.xwayland
    clipboard.helper
    # Terminal for `vm-run <vm> foot`, configured like dom0's foot
    pkgs.foot
  ];

  # An old copy of the unit in the home (chat, from before it was a system
  # unit) shadowed this one, without the clipboard isolation (2026-10-16)
  systemd.tmpfiles.rules = [
    "r /home/user/.config/systemd/user/default.target.wants/wprsd.service"
    "r /home/user/.config/systemd/user/wprsd.service"
  ];

  environment.etc."xdg/foot/foot.ini".text = lib.generators.toINI { } theme.foot;
}
