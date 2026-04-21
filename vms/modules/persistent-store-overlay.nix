{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.persistentStoreOverlay;

  nixDumpOverlayDb = pkgs.writeShellScript "nix-db-dump.sh" ''
    set +e

    db="/persist/overlay.db"
    tmp_roots="$(mktemp)"
    tmp_valid_roots="$(mktemp)"
    tmp_closure="$(mktemp)"
    tmp_filtered="$(mktemp)"

    cleanup() {
      rm -f "$tmp_roots" "$tmp_valid_roots" "$tmp_closure" "$tmp_filtered"
    }
    trap cleanup EXIT # Call cleanup() on exit

    : > "$db"

    add_root() {
      local p="$1"
      # $p exists?
      [ -e "$p" ] || return 0
      readlink -f "$p" >> "$tmp_roots"
    }

    # Profiles
    for p in \
      /nix/var/nix/profiles/system \
      /nix/var/nix/profiles/default \
      /nix/var/nix/profiles/per-user/*/profile \
      /nix/var/nix/profiles/per-user/*/home-manager
    do
      add_root "$p"
    done

    # GC roots
    while IFS= read -r root; do
      add_root "$root"
    done < <(find /nix/var/nix/gcroots /nix/var/nix/gcroots/per-user -type l 2>/dev/null)

    # Derive unique roots
    sort -u "$tmp_roots" -o "$tmp_roots"

    # Only keep valid roots
    while IFS= read -r root; do
      ${pkgs.nix}/bin/nix-store --verify-path "$root" >/dev/null 2>&1
      # Check for success of the last command, i.e. Exit-Code 0
      if [ $? -eq 0 ]; then
        printf '%s\n' "$root" >> "$tmp_valid_roots"
      fi
    done < "$tmp_roots"

    # Collect closure per root
    while IFS= read -r root; do
      ${pkgs.nix}/bin/nix-store -qR "$root" >> "$tmp_closure" 2>/dev/null
    done < "$tmp_valid_roots"

    sort -u "$tmp_closure" -o "$tmp_closure"

    # Keep only paths physically present in the writable overlay
    while IFS= read -r path; do
      base="$(basename "$path")"
      if [ -e "/nix/.rw-store/store/$base" ]; then
        printf '%s\n' "$path" >> "$tmp_filtered"
      fi
    done < "$tmp_closure"

    sort -u "$tmp_filtered" -o "$tmp_filtered"

    # Dump the filtered paths to the DB file
    if [ -s "$tmp_filtered" ]; then
      ${pkgs.findutils}/bin/xargs -r ${pkgs.nix}/bin/nix-store --dump-db < "$tmp_filtered" > "$db"
    fi
  '';

  nixLoadOverlayDb = pkgs.writeShellScript "nix-db-restore.sh" ''
    set +e
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

    nix.settings = {
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
        cfg.user
      ];
    };
    systemd.services.nix-db-backup = {
      description = "Backup overlay-related Nix DB entries on shutdown";
      wantedBy = [ "multi-user.target" ];
      before = [ "shutdown.target" ];
      after = [ "local-fs.target" ];

      unitConfig.RequiresMountsFor = [
        "/nix"
        "/persist"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = "${nixDumpOverlayDb}";
        User = "root";
        TimeoutStopSec = "5min";
      };
    };

    systemd.services.nix-db-restore = {
      description = "Restore overlay-related Nix DB entries at boot";
      wantedBy = [ "multi-user.target" ];
      before = [ "multi-user.target" ];
      after = [ "local-fs.target" ];

      unitConfig.RequiresMountsFor = [
        "/nix"
        "/persist"
      ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${nixLoadOverlayDb}";
        User = "root";
        TimeoutSec = "5min";
      };
    };
  };
}
