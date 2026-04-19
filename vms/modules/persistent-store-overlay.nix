{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.persistentStoreOverlay;
  nixDbRestoreScript = pkgs.writeShellScript "nix-db-restore.sh" ''
    if [ -d /persist/nix-db-backup ] && [ "$(ls -A /persist/nix-db-backup)" ]; then
      exec ${pkgs.rsync}/bin/rsync -a /persist/nix-db-backup/ /nix/var/nix/db/
    fi
  '';
in
{
  options.services.persistentStoreOverlay = {
    enable = lib.mkEnableOption "Enable persistent store overlay for microvms";

    dbDir = lib.mkOption {
      type = lib.types.path;
      default = ./persist/nix-db-backup;
      description = "Directory to store the Nix database backup.";
    };

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

  config = lib.mkIf cfg.enable {
    microvm = {
      writableStoreOverlay = "/nix/.rw-store";
      volumes = lib.mkAfter [
        {
          image = "nix-store-overlay.img";
          mountPoint = "/nix/.rw-store";
          size = cfg.overlaySize;
        }
        {
          image = "nix-db.img";
          mountPoint = cfg.dbDir;
          size = cfg.dbDirSize;
        }
      ];
      shares = lib.mkAfter [
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
        auto-optimise-store = true;
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
        ExecStart = "${pkgs.rsync}/bin/rsync -a --delete /nix/var/nix/db/ /persist/nix-db-backup/";
      };
    };
    systemd.services.nix-db-restore = {
      description = "Restore Nix DB at boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${nixDbRestoreScript}";
      };
    };
  };
}
