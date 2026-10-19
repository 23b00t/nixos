# vm-backup (`nox backup`, xen-migration.md "Spec Backup"): two workflows onto
# an external LUKS disk that hangs on the disposable disp-backup (USB/IP from
# sys-usb). dom0 mounts no guest file system and has no SSH into the VMs:
# - W1 (default): /home/user of the chosen VMs, incremental (rsync
#   --link-dest, one folder per run). disp-backup's rsync talks to the VM's
#   rpc service `backup-send` (read-only sender) / `backup-recv` (--update),
#   vms/modules/vchan-relay.nix; only disp-backup may call them.
# - W2 (--full): whole volume images (registry VMs: their microvm.volumes;
#   image domains: the raw image; builder: only its signing key; dom0: ~/.ssh
#   and ~/vm-images without the image domains' images) as a zstd stream from
#   dom0 into disp-backup, one copy per image, replaced only after a
#   complete write, sha256 of the raw image next to it.
# disp-backup's side: rpc service `backup` (vms/disp-backup).
{
  lib,
  pkgs,
  osConfig ? { },
  vmRegistry,
  ...
}:
let
  vms = osConfig.microvm.vms or { };
  imageDomains = osConfig.services.xen-image-domains.domains or { };
  # W2 entries: "name kind path…" per line; kind vm = images under
  # /var/lib/microvms/<name>, image = one raw file, key = builder's key
  fullTable = pkgs.writeText "vm-backup-full" (
    lib.concatStrings (
      lib.mapAttrsToList (
        name: vm:
        let
          images = map (v: v.image) (vm.config.config.microvm.volumes or [ ]);
        in
        if name == "builder" then
          "builder key\n"
        else
          lib.optionalString (images != [ ]) "${name} vm ${lib.concatStringsSep " " images}\n"
      ) vms
      ++ lib.mapAttrsToList (name: d: "${name} image ${d.image}\n") imageDomains
    )
    + "dom0 dom0\n"
  );
  # W1: VMs with a /home worth keeping (registry `backup`), preselected
  w1Vms = map (vm: vm.name) (builtins.filter (vm: vms ? ${vm.name}) vmRegistry.backupVms);
  allW1 = map (vm: vm.name) (
    builtins.filter (vm: vms ? ${vm.name} && vm.name != "disp-backup") vmRegistry.vms
  );
  diskName = "backup-disk";
  hasDisk = (vmRegistry.hardware.usb.byName or { }) ? ${diskName};
  imageNames = lib.attrNames imageDomains;

  vmBackup = pkgs.writeShellScriptBin "vm-backup" ''
    set -uo pipefail
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gawk
        pkgs.zstd
        pkgs.gnutar
        pkgs.rofi
        pkgs.libnotify
      ]
    }:$PATH
    full=${fullTable}
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/nox-backup"
    level=3
    die() { echo "vm-backup: $*" >&2; exit 1; }
    usage() {
      cat >&2 <<'USAGE'
    usage: vm-backup [vm…|--all]                    W1: /home of the VMs (no args: checklist)
           vm-backup --full [--level N] [vm…|--all] W2: whole images (no args: checklist)
           vm-backup restore [--from <run>] <vm…|--all>   W1 back, in place (--update)
           vm-backup restore --full <vm…|--all>           W2 back (replaces the images)
           vm-backup list
           vm-backup prune --keep N [-n]             W1: keep the newest N runs per VM
    USAGE
      exit 2
    }

    # disp-backup's `backup` service: command on the first line, its output,
    # `exit <rc>` as the last line (a stream keeps going to the terminal)
    call() { # call <command line> [stdin from caller]
      local out rc
      out="$( { printf '%s\n' "$1"; [ -t 0 ] || cat; } | nox-rpc --dom0 backup disp-backup | tee /dev/stderr | tail -n 1)"
      rc="''${out#exit }"
      [[ "$rc" =~ ^[0-9]+$ ]] || return 1
      return "$rc"
    }
    unit_of() {
      case " ${lib.concatStringsSep " " imageNames} " in
        *" $1 "*) echo "xen-image@$1" ;;
        *) echo "microvm@$1" ;;
      esac
    }
    running() { systemctl is-active --quiet "$(unit_of "$1").service"; }
    wait_rpc() {
      for _ in $(seq 120); do
        [ "$(timeout 5 nox-rpc --dom0 ping "$1" </dev/null 2>/dev/null)" = ok ] && return 0
        sleep 1
      done
      return 1
    }

    session_open() {
      echo "vm-backup: starting disp-backup" >&2
      manage-vms start disp-backup >/dev/null || die "disp-backup does not start"
      wait_rpc disp-backup || die "disp-backup does not answer"
      ${
        if hasDisk then
          ''vm-usb attach ${diskName} disp-backup || die "attach of ${diskName} failed (plugged in?)"''
        else
          ''
            # No `${diskName}` in the registry's USB inventory: pick by busid
            vm-usb list
            read -r -p "busid of the backup disk: " busid
            vm-usb attach "$busid" disp-backup || die "attach of $busid failed"
          ''
      }
      read -r -s -p "LUKS passphrase of the backup disk: " pw
      echo >&2
      { printf 'open\n%s\n' "$pw"; } | nox-rpc --dom0 backup disp-backup | tail -n 1 | grep -qx "exit 0" \
        || die "could not open the backup disk"
      unset pw
      trap session_close EXIT
    }
    session_close() {
      call close </dev/null || echo "vm-backup: closing the disk failed, check before unplugging" >&2
      manage-vms stop disp-backup >/dev/null || true
    }

    # Chosen VMs: args, --all, or a rofi checklist (preselected rows first)
    choose() { # choose <all…> -- <preselected…> -- <args…>
      local all=() pre=() args=() part=0 x
      for x in "$@"; do
        if [ "$x" = -- ]; then part=$((part + 1)); continue; fi
        case $part in 0) all+=("$x") ;; 1) pre+=("$x") ;; *) args+=("$x") ;; esac
      done
      if [ "''${#args[@]}" -gt 0 ]; then
        if [ "''${args[0]}" = --all ]; then printf '%s\n' "''${all[@]}"; return; fi
        for x in "''${args[@]}"; do
          printf '%s\n' "''${all[@]}" | grep -qx "$x" || die "unknown or excluded: $x"
          echo "$x"
        done
        return
      fi
      local sel="" i=0
      for x in "''${all[@]}"; do
        printf '%s\n' "''${pre[@]}" | grep -qx "$x" && sel="$sel''${sel:+,}$i"
        i=$((i + 1))
      done
      printf '%s\n' "''${all[@]}" | rofi -dmenu -multi-select -p backup -a "$sel" -selected-row 0
    }

    w1() {
      local vm stamp rc=0 was
      stamp="$(date +%Y-%m-%d_%H%M%S)"
      for vm in "$@"; do
        was=1
        if ! running "$vm"; then
          was=0
          systemctl start "$(unit_of "$vm")" || { echo "vm-backup: $vm does not start" >&2; rc=1; continue; }
        fi
        if wait_rpc "$vm"; then
          echo "vm-backup: $vm" >&2
          call "w1 $vm $stamp" </dev/null || { echo "vm-backup: $vm failed" >&2; rc=1; }
        else
          echo "vm-backup: $vm does not answer" >&2
          rc=1
        fi
        [ "$was" = 1 ] || systemctl stop "$(unit_of "$vm")"
      done
      if [ "$rc" = 0 ]; then
        mkdir -p "$state"
        date +%s >"$state/last"
      fi
      return "$rc"
    }

    w1_restore() {
      local from="$1" vm rc=0 was
      shift
      for vm in "$@"; do
        was=1
        if ! running "$vm"; then
          was=0
          systemctl start "$(unit_of "$vm")" || { rc=1; continue; }
        fi
        if wait_rpc "$vm"; then
          call "restore $vm $from" </dev/null || rc=1
        else
          rc=1
        fi
        [ "$was" = 1 ] || systemctl stop "$(unit_of "$vm")"
      done
      return "$rc"
    }

    # One W2 stream: the bytes on stdin under <name>/<file>; sha256 of the raw
    # bytes goes along for the commit
    put() { # put <name> <file> < raw bytes
      local tmp sum
      tmp="$(mktemp -d)"
      { printf 'w2-put %s %s\n' "$1" "$2"
        tee >(sha256sum | cut -d' ' -f1 >"$tmp/sum") | zstd -T0 -q -"$level" -c
      } | nox-rpc --dom0 backup disp-backup | tail -n 1 | grep -qx "exit 0" || { rm -rf "$tmp"; return 1; }
      for _ in $(seq 600); do [ -s "$tmp/sum" ] && break; sleep 0.1; done
      sum="$(cat "$tmp/sum")"
      rm -rf "$tmp"
      [ -n "$sum" ] && call "w2-commit $1 $2 $sum" </dev/null >/dev/null
    }
    get() { # get <name> <file> <target path> (sudo writes it, sparse)
      local tmp sum
      tmp="$(mktemp -d)"
      printf 'w2-get %s %s\n' "$1" "$2" | nox-rpc --dom0 backup disp-backup \
        | { IFS= read -r sum; echo "$sum" >"$tmp/sum"; sudo zstd -d -q -f --sparse -o "$3.restore"; } || { rm -rf "$tmp"; return 1; }
      sum="$(cat "$tmp/sum")"
      rm -rf "$tmp"
      [ "$(sudo sha256sum "$3.restore" | cut -d' ' -f1)" = "$sum" ] || { echo "vm-backup: checksum of $1/$2 wrong, kept $3" >&2; sudo rm -f "$3.restore"; return 1; }
      [ ! -e "$3" ] || sudo chown --reference="$3" "$3.restore"
      sudo mv -f "$3.restore" "$3"
    }

    w2_one() { # w2_one put|get <name>
      local op="$1" name="$2" kind paths p
      read -r _ kind paths < <(awk -v n="$name" '$1 == n' "$full")
      case "$kind" in
        vm)
          for p in $paths; do
            [ -e "/var/lib/microvms/$name/$p" ] || continue
            if [ "$op" = put ]; then put "$name" "$p" <"/var/lib/microvms/$name/$p" || return 1
            else get "$name" "$p" "/var/lib/microvms/$name/$p" || return 1; fi
          done
          ;;
        image)
          if [ "$op" = put ]; then put "$name" image.raw <"$paths" || return 1
          else get "$name" image.raw "$paths" || return 1; fi
          ;;
        key)
          # The builder keeps SSH (dom0-update); its cache stays out
          if [ "$op" = put ]; then ssh builder sudo cat /var/lib/builder/signing-key | put builder signing-key || return 1
          else echo "vm-backup: builder key: restore by hand (w2-get builder signing-key)" >&2; fi
          ;;
        dom0)
          if [ "$op" = put ]; then
            # The image domains' images are entries of their own
            tar -C "$HOME" \
              ${
                lib.concatStrings (
                  lib.mapAttrsToList (
                    _: d: "--exclude=${lib.escapeShellArg (lib.removePrefix "/home/nx/" d.image)} "
                  ) imageDomains
                )
              } \
              -cf - .ssh $( [ -d "$HOME/vm-images" ] && echo vm-images ) \
              | put dom0 home.tar || return 1
          else
            echo "vm-backup: dom0 files: restore by hand (w2-get dom0 home.tar | zstd -d | tar -x)" >&2
          fi
          ;;
        *) echo "vm-backup: nothing to back up for $name" >&2 ;;
      esac
    }

    w2() { # w2 put|get <name…>
      local op="$1" name rc=0 restart=()
      shift
      local up=()
      for name in "$@"; do
        case "$name" in dom0 | builder) continue ;; esac
        running "$name" && up+=("$name")
      done
      if [ "''${#up[@]}" -gt 0 ]; then
        read -r -p "vm-backup: stops and restarts: ''${up[*]}. Go on? [y/N] " a
        [ "$a" = y ] || [ "$a" = Y ] || die "aborted"
      fi
      if [ "$op" = get ]; then
        read -r -p "vm-backup: replaces the images of: $*. Sure? [y/N] " a
        [ "$a" = y ] || [ "$a" = Y ] || die "aborted"
      fi
      for name in "$@"; do
        if printf '%s\n' "''${up[@]}" | grep -qx "$name"; then
          systemctl stop "$(unit_of "$name")" || { rc=1; continue; }
          restart+=("$name")
        fi
        echo "vm-backup: $name" >&2
        w2_one "$op" "$name" || { echo "vm-backup: $name failed" >&2; rc=1; }
        if printf '%s\n' "''${restart[@]}" | grep -qx "$name"; then
          systemctl start "$(unit_of "$name")" || rc=1
        fi
      done
      return "$rc"
    }

    allFull=( $(awk '{ print $1 }' "$full") )
    case "''${1:-}" in
      -h | --help) usage ;;
      list)
        session_open
        call list </dev/null
        ;;
      prune)
        [ "''${2:-}" = --keep ] && [[ "''${3:-}" =~ ^[0-9]+$ ]] || usage
        session_open
        call "prune $3 ''${4:-}" </dev/null
        ;;
      restore)
        shift
        if [ "''${1:-}" = --full ]; then
          shift
          [ $# -gt 0 ] || usage
          mapfile -t sel < <(choose "''${allFull[@]}" -- -- "$@")
          session_open
          w2 get "''${sel[@]}"
        else
          from=latest
          if [ "''${1:-}" = --from ]; then from="''${2:?}"; shift 2; fi
          [ $# -gt 0 ] || usage
          mapfile -t sel < <(choose ${lib.concatStringsSep " " allW1} -- -- "$@")
          session_open
          w1_restore "$from" "''${sel[@]}"
        fi
        ;;
      --full)
        shift
        if [ "''${1:-}" = --level ]; then level="''${2:?}"; shift 2; fi
        mapfile -t sel < <(choose "''${allFull[@]}" -- -- "$@")
        [ "''${#sel[@]}" -gt 0 ] || die "nothing chosen"
        session_open
        w2 put "''${sel[@]}"
        ;;
      *)
        mapfile -t sel < <(choose ${lib.concatStringsSep " " allW1} -- ${lib.concatStringsSep " " w1Vms} -- "$@")
        [ "''${#sel[@]}" -gt 0 ] || die "nothing chosen"
        session_open
        w1 "''${sel[@]}"
        ;;
    esac
  '';

  # Reminder: no W1 for 7 days (also a row in vm-doctor)
  reminder = pkgs.writeShellScript "vm-backup-reminder" ''
    last="$(cat "''${XDG_STATE_HOME:-$HOME/.local/state}/nox-backup/last" 2>/dev/null || echo 0)"
    if [ $(( $(${pkgs.coreutils}/bin/date +%s) - last )) -gt $((7 * 86400)) ]; then
      ${pkgs.libnotify}/bin/notify-send -a vm-backup "Backup" "Letztes Backup älter als 7 Tage: nox backup"
    fi
  '';
in
{
  home.packages = [ vmBackup ];

  systemd.user = {
    services.vm-backup-reminder = {
      Unit.Description = "Remind of the backup after 7 days";
      Service = {
        Type = "oneshot";
        ExecStart = "${reminder}";
      };
    };
    timers.vm-backup-reminder = {
      Unit.Description = "Daily backup reminder";
      Timer = {
        OnStartupSec = "10min";
        OnUnitActiveSec = "1d";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
