# disp-backup: disposable for `nox backup` (spec in xen-migration.md "Spec
# Backup"): holds the backup disk (USB/IP from sys-usb), no network, empty
# home on every start (registry `disposable`, machines/xen-dom0.nix). dom0's
# vm-backup (home/vm-management/vm-backup.nix) drives it over the rpc
# service `backup` below; the disk is LUKS, opened with the passphrase dom0
# sends. Layout on the disk: nox/home/<vm>/<run>/ (W1, hard links to the
# previous run), nox/full/<name>/<file>.zst + .sha256 (W2, raw sha256).
{
  lib,
  pkgs,
  config,
  ...
}:
let
  mnt = "/mnt/backup";
  noxRpc = "${config.services.nox-rpc.package}/bin/nox-rpc";
  # rsync's remote shell: `<rsh> <vm> rsync --server …` becomes a call of
  # the VM's backup-send/backup-recv with that command as the first line
  rsh =
    service:
    pkgs.writeShellScript "backup-rsh-${service}" ''
      host="$1"
      shift
      { printf '%s\n' "$*"; exec ${pkgs.coreutils}/bin/cat; } | exec ${noxRpc} ${service} "$host"
    '';
  rsyncOpts = "-aHS --numeric-ids --info=stats1,progress2";

  # Root part of the service (sudo from the handler). Names are checked:
  # they end up in paths
  helper = pkgs.writeShellScript "backup-helper" ''
    set -uo pipefail
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.util-linux
        pkgs.cryptsetup
        pkgs.rsync
        pkgs.findutils
        pkgs.gnugrep
      ]
    }
    name_ok() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]]; }
    file_ok() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; }
    run_ok() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$ ]]; }
    home="${mnt}/nox/home"
    full="${mnt}/nox/full"
    latest() { find "$home/$1" -mindepth 1 -maxdepth 1 -type d -regex '.*/[0-9_-]*' -printf '%f\n' 2>/dev/null | sort | tail -n 1; }

    case "$1" in
      open)
        # The disk is the only sd* here (own disks are xvd*); LUKS on the
        # whole disk or on a partition
        IFS= read -r pw || exit 1
        dev=""
        for _ in $(seq 30); do
          for d in /dev/sd?*; do
            [ -b "$d" ] && cryptsetup isLuks "$d" 2>/dev/null && { dev="$d"; break 2; }
          done
          sleep 1
        done
        [ -n "$dev" ] || { echo "no LUKS disk found"; exit 1; }
        printf '%s' "$pw" | cryptsetup open --key-file=- "$dev" noxbackup || exit 1
        mkdir -p ${mnt}
        mount /dev/mapper/noxbackup ${mnt} || { cryptsetup close noxbackup; exit 1; }
        mkdir -p "$home" "$full"
        echo "opened $dev"
        ;;
      close)
        sync
        if mountpoint -q ${mnt}; then umount ${mnt} || exit 1; fi
        if [ -e /dev/mapper/noxbackup ]; then cryptsetup close noxbackup || exit 1; fi
        echo "closed"
        ;;
      w1)
        name_ok "$2" && run_ok "$3" || exit 2
        prev="$(latest "$2")"
        mkdir -p "$home/$2"
        rsync ${rsyncOpts} --exclude=/.cache \
          ''${prev:+--link-dest="$home/$2/$prev"} \
          -e ${rsh "backup-send"} "$2:/home/user/" "$home/$2/$3.partial/" || exit 1
        mv "$home/$2/$3.partial" "$home/$2/$3"
        ;;
      restore)
        name_ok "$2" || exit 2
        run="$3"
        [ "$run" = latest ] && run="$(latest "$2")"
        run_ok "$run" && [ -d "$home/$2/$run" ] || { echo "no run $3 for $2"; exit 1; }
        rsync ${rsyncOpts} --update \
          -e ${rsh "backup-recv"} "$home/$2/$run/" "$2:/home/user/"
        ;;
      list)
        echo "W1 (home):"
        for d in "$home"/*/; do
          [ -d "$d" ] || continue
          printf '  %s: %s\n' "$(basename "$d")" "$(find "$d" -mindepth 1 -maxdepth 1 -type d -regex '.*/[0-9_-]*' -printf '%f ' | tr ' ' '\n' | sort | tr '\n' ' ')"
        done
        echo "W2 (full):"
        for d in "$full"/*/; do
          [ -d "$d" ] || continue
          printf '  %s: %s\n' "$(basename "$d")" "$(cd "$d" && ls -l --time-style=+%F *.zst 2>/dev/null | awk '{ printf "%s (%s, %s) ", $7, $5, $6 }')"
        done
        df -h ${mnt} | tail -n 1
        ;;
      prune)
        [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -ge 1 ] || exit 2
        for d in "$home"/*/; do
          [ -d "$d" ] || continue
          find "$d" -mindepth 1 -maxdepth 1 -type d -regex '.*/[0-9_-]*' -printf '%f\n' | sort | head -n -"$2" \
            | while read -r r; do
                echo "remove $(basename "$d")/$r"
                [ "''${3:-}" = -n ] || rm -rf "''${d%/}/$r"
              done
        done
        ;;
      w2-put)
        # Written next to the old copy, which stays until the commit
        name_ok "$2" && file_ok "$3" || exit 2
        mkdir -p "$full/$2"
        cat >"$full/$2/$3.zst.new" || exit 1
        ;;
      w2-commit)
        name_ok "$2" && file_ok "$3" && [[ "$4" =~ ^[0-9a-f]{64}$ ]] || exit 2
        [ -s "$full/$2/$3.zst.new" ] || exit 1
        mv -f "$full/$2/$3.zst.new" "$full/$2/$3.zst"
        echo "$4" >"$full/$2/$3.sha256"
        sync
        ;;
      w2-get)
        # First line the raw sha256, then the zstd stream (no status line)
        name_ok "$2" && file_ok "$3" && [ -s "$full/$2/$3.zst" ] || exit 2
        cat "$full/$2/$3.sha256"
        exec cat "$full/$2/$3.zst"
        ;;
      *) exit 2 ;;
    esac
  '';
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
  ];

  networking.hostName = "disp-backup-vm";

  microvm = {
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 20000;
      }
    ];
    mem = 1024;
    vcpu = 2;
  };

  services = {
    net-config = {
      enable = true;
      index = 32;
      mac = "00:00:00:00:00:20";
    };

    common-config = {
      enable = true;
      withDefaultPkgs = false;
    };

    # dom0's vm-backup: first line `<command> [args]`, the output, then
    # `exit <rc>`; w2-get streams without a status line
    nox-rpc.guest.handlers.backup = ''
      if [ "$source" != dom0 ]; then
        echo "error: only dom0"
        exit 1
      fi
      IFS= read -r line || exit 1
      read -ra args <<<"$line"
      if [ "''${args[0]:-}" = w2-get ]; then
        exec /run/wrappers/bin/sudo ${helper} "''${args[@]}"
      fi
      /run/wrappers/bin/sudo ${helper} "''${args[@]}" 2>&1
      echo "exit $?"
    '';
  };

  environment.systemPackages = with pkgs; [
    cryptsetup
    rsync
  ];

  system.stateVersion = "26.05";
}
