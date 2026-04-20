{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.persistentStoreOverlay;
  nixDumpOverlayDb = pkgs.writeShellScript "nix-db-dump.sh" ''
    ${pkgs.findutils}/bin/find /nix/.rw-store/store -mindepth 1 -maxdepth 1 -type d \
      | ${pkgs.gnused}/bin/sed 's#^/nix/.rw-store/store#/nix/store#' \
      | ${pkgs.findutils}/bin/xargs ${pkgs.nix}/bin/nix-store --dump-db > /persist/overlay.db
  '';

  nixLoadOverlayDb = pkgs.writeShellScript "nix-db-restore.sh" ''
    if [ -f /persist/overlay.db ] && [ -s /persist/overlay.db ]; then
      ${pkgs.nix}/bin/nix-store --load-db < /persist/overlay.db
    fi
  '';
in
{
  options.services.persistentStoreOverlay = {
    enable = lib.mkEnableOption "Enable persistent store overlay for microvms";

    user = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "VM user";
    };

    overlaySize = lib.mkOption {
      type = lib.types.int;
      default = 23000;
      description = "Size of the writable store overlay in MB.";
    };

    dbDirSize = lib.mkOption {
      type = lib.types.int;
      default = 512;
      description = "Size of the Nix DB overlay in MB.";
    };
  };

  config = lib.mkIf cfg.enable {
    microvm = {
      writableStoreOverlay = "/nix/.rw-store";
      volumes = [
        {
          image = "nix-store-overlay.img";
          mountPoint = "/nix/.rw-store";
          size = cfg.overlaySize;
        }
        {
          image = "nix-db.img";
          mountPoint = "/persist";
          size = cfg.dbDirSize;
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
    };
    # use cache
    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [
          "https://cache.nixos.org"
          "https://microvm.cachix.org"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
        trusted-users = [
          "root"
          cfg.user
        ];
      };
    };

    # systemd units for Nix DB backup/restore
    systemd.services.nix-db-backup = {
      description = "Backup Nix DB before shutdown";
      wantedBy = [ "shutdown.target" ];
      before = [ "shutdown.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${nixDumpOverlayDb}";
      };
    };
    systemd.services.nix-db-restore = {
      description = "Restore Nix DB at boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${nixLoadOverlayDb}";
      };
    };
  };
}
