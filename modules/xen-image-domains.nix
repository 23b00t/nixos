# Image domains (v3): guests from upstream disk images (Whonix), not NixOS
# and not run by microvm.nix. Per domain one xl config and the unit
# `xen-image@<name>`. PVH guests boot their own kernel with pvgrub2 (reads
# /boot/grub/grub.cfg from the guest disk), so the guest keeps updating it.
#
# Guest integration without Nix in the guest: a read-only store disk
# (squashfs of a Nix closure, mounted at /nix/store, stable entry point
# /nix/store/nox) carries nox-relay, sshd and, for driver domains, `xl devd`
# with the hotplug scripts. `xen-image-setup <name>` installs the systemd
# units into the stopped image once (debugfs, as the image owner); later
# store disks keep working with the same units.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.xen-image-domains;
  xen = config.virtualisation.xen.package;
  relayPackage = config.services.nox-relay.package;
  pvhgrub = "${pkgs.grub2_pvhgrub_image}/lib/grub-xen_pvh/grub-i386-xen_pvh.bin";

  quote = s: ''"${s}"'';
  xlList = items: "[ ${lib.concatMapStringsSep ", " quote items} ]";

  # Socket of sshd -i in the guest, served to dom0 over the relay
  guestSshSocket = "/run/nox-sshd.sock";

  vifOpts = {
    options = {
      mac = lib.mkOption {
        type = lib.types.str;
        description = "MAC address of the guest interface.";
      };
      bridge = lib.mkOption {
        type = lib.types.str;
        description = "Bridge in the backend domain.";
      };
      backend = lib.mkOption {
        type = lib.types.str;
        default = "sys-net-vm";
        description = "Xen domain serving the vif (driver domain).";
      };
      backendAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.0.0.253";
        description = "Admin address (port 22) or relay SSH socket of the backend, to wait for it.";
      };
      waitForUplink = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Also wait until the backend reports a ready uplink (`data/uplink` = 1 in its xenstore, written by sys-net).";
      };
    };
  };

  relayRules = {
    listen = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Relay `listen` rules (see services.nox-relay).";
    };
    serve = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Relay `serve` rules (see services.nox-relay).";
    };
  };

  domainOpts =
    { name, ... }:
    {
      options = {
        domain = lib.mkOption {
          type = lib.types.str;
          default = "${name}-vm";
          description = "Xen domain name.";
        };
        image = lib.mkOption {
          type = lib.types.str;
          description = "Raw disk image (read-write, xvda).";
        };
        rootPartition = lib.mkOption {
          type = lib.types.ints.positive;
          description = "Partition of the image holding the root file system (ext4), for `xen-image-setup`.";
        };
        memory = lib.mkOption {
          type = lib.types.ints.positive;
          description = "Memory in MiB (fixed, no ballooning).";
        };
        vcpus = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1;
          description = "Number of vCPUs.";
        };
        autostart = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Start the domain at boot.";
        };
        vifs = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule vifOpts);
          default = [ ];
          description = "Network interfaces (eth0, eth1, … in order), re-attached by xen-links.";
        };
        authorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Keys dom0 logs in with as `user` (sshd over the relay).";
        };
        driverDomain = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Serve vifs for other domains (`xl devd` in the guest).";
        };
        internalBridge = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Bridge the driver domain creates for its vifs; every port is isolated (clients reach the domain, not each other).";
        };
        ifupdownHotplug = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Interfaces ifupdown raises again when they reappear (vif re-attached after a backend restart).";
        };
        wprs = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "GUI apps over wprs (wprsd as user service, socket over the relay; `vm-gui` starts apps over SSH) with dom0's pulse.";
        };
        relay = {
          host = relayRules;
          guest = relayRules;
        };
        sysmaintEntry = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "PERSISTENT Mode | SYSMAINT Session | system maintenance tasks";
          description = ''
            GRUB menu entry of the guest's sysmaint session (Kicksecure
            user-sysmaint-split: updates only work there). When set, the next
            start boots this entry if /run/xen-image/<name>.sysmaint exists
            (removed on start), dom0 may also log in as `sysmaint`, and the
            dom0 integration runs in sysmaint-boot.target too.
          '';
        };
        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Extra xl.cfg lines.";
        };
      };
    };

  # Store disk: the closure of `env` as a squashfs, store paths at the top
  # level (mounted at /nix/store in the guest), plus the symlink `nox` -> env
  mkGuest =
    name: d:
    let
      sshdConfig = pkgs.writeText "sshd_config" ''
        HostKey /var/lib/nox/ssh/ssh_host_ed25519_key
        AuthorizedKeysFile /nix/store/nox/etc/ssh/authorized_keys/%u
        AllowUsers user${lib.optionalString (d.sysmaintEntry != null) " sysmaint"}
        # DenyUsers for the account of the other session (nox-sshd-setup)
        Include ${sshdSessionConfig}
        PermitRootLogin no
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        UsePAM no
        AllowAgentForwarding no
        AllowTcpForwarding no
        AllowStreamLocalForwarding no
        X11Forwarding no
        PermitTunnel no
        PrintMotd no
        # Login environment of the distribution (Whonix sets e.g. the Tor Browser
        # variables in /etc/profile.d), see nox-session
        ForceCommand /nix/store/nox/bin/nox-session
        Subsystem sftp ${pkgs.openssh}/libexec/sftp-server
        ${lib.optionalString d.wprs ''
          # Without PAM there is no login session: apps started over SSH
          # (vm-gui) find wprsd's socket here
          SetEnv XDG_RUNTIME_DIR=/run/user/1000
        ''}
      '';

      wprsClipboard = import ./wprs-clipboard.nix { inherit pkgs; };

      # Written at boot by nox-sshd-setup
      sshdSessionConfig = "/run/nox-sshd-session.conf";

      # Same paths as in the NixOS VMs (vms/modules/vchan-relay.nix); the
      # user's group is 1000 in Debian
      relayRulesGuest = {
        listen =
          d.relay.guest.listen
          // lib.optionalAttrs d.wprs {
            pulse = {
              path = "/tmp/wprs-pulse";
              owner = "1000:1000";
            };
          };
        serve =
          d.relay.guest.serve
          // {
            ssh = guestSshSocket;
          }
          // lib.optionalAttrs d.wprs { wprs = "/run/user/1000/wprs.sock"; };
      };
      relayConfig = pkgs.writeText "nox-relay.conf" (
        lib.concatStrings (
          lib.mapAttrsToList (
            service: l:
            "listen ${service} ${l.path} mode=${l.mode or "0600"}"
            + lib.optionalString ((l.owner or null) != null) " owner=${l.owner}"
            + "\n"
          ) relayRulesGuest.listen
          ++ lib.mapAttrsToList (service: path: "serve ${service} ${path}\n") relayRulesGuest.serve
        )
      );

      # Runs as root before the first SSH connection: privilege separation
      # user and directory of sshd, host key
      sshdSetup = pkgs.writeShellScript "nox-sshd-setup" ''
        set -eu
        PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.openssh
          ]
        }:/usr/sbin:/usr/bin
        getent passwd sshd >/dev/null ||
          useradd --system --no-create-home --home-dir /var/empty --shell /usr/sbin/nologin sshd
        install -d -m 0555 /var/empty
        install -d -m 0700 /var/lib/nox/ssh
        [ -e /var/lib/nox/ssh/ssh_host_ed25519_key ] ||
          ssh-keygen -q -t ed25519 -N "" -f /var/lib/nox/ssh/ssh_host_ed25519_key
        # Kicksecure user-sysmaint-split: only the account of the booted
        # session may log in. sshd runs without PAM, which enforces this for
        # local logins
        if grep -qw boot-role=sysmaint /proc/cmdline; then
          echo "DenyUsers user" >${sshdSessionConfig}
        else
          echo "DenyUsers sysmaint" >${sshdSessionConfig}
        fi
      '';

      # sshd ForceCommand: what a Debian login sets up (/etc/profile.d) without
      # its output (welcome texts would end up in vm-run -c), then the command
      # (or an interactive login) in the user's shell
      session = pkgs.writeScript "nox-session" ''
        #!${pkgs.bash}/bin/bash
        for f in /etc/profile.d/*.sh; do
          [ -r "$f" ] && . "$f" >/dev/null 2>&1
        done
        if [ -n "''${SSH_ORIGINAL_COMMAND:-}" ]; then
          exec "$SHELL" -c "$SSH_ORIGINAL_COMMAND"
        fi
        exec "$SHELL" -l
      '';

      # Default hotplug scripts, vif-bridge additionally isolates the port
      xenScripts = pkgs.runCommand "nox-xen-scripts" { } ''
        mkdir -p $out
        for f in ${xen}/etc/xen/scripts/*; do
          ln -s "$f" $out/
        done
        rm $out/vif-bridge
        cat > $out/vif-bridge <<'EOF'
        #!${pkgs.bash}/bin/bash
        # vif-bridge, then the port gets isolated: clients of this driver
        # domain reach it, not each other
        ${xen}/etc/xen/scripts/vif-bridge "$@" || exit
        case "$1" in
          online | add) ${pkgs.iproute2}/bin/ip link set dev "$vif" type bridge_slave isolated on ;;
        esac
        EOF
        chmod 0555 $out/vif-bridge
      '';

      env = pkgs.runCommand "nox-guest-${name}" { } ''
        mkdir -p $out/bin $out/etc/ssh/authorized_keys
        ln -s ${relayPackage}/bin/nox-relay $out/bin/nox-relay
        ln -s ${pkgs.openssh}/bin/sshd $out/bin/sshd
        ln -s ${sshdSetup} $out/bin/nox-sshd-setup
        ln -s ${session} $out/bin/nox-session
        ln -s ${relayConfig} $out/etc/nox-relay.conf
        ln -s ${sshdConfig} $out/etc/ssh/sshd_config
        cp ${pkgs.writeText "authorized_keys" (lib.concatMapStrings (k: "${k}\n") d.authorizedKeys)} \
          $out/etc/ssh/authorized_keys/user
        ${lib.optionalString (d.sysmaintEntry != null) "ln -s user $out/etc/ssh/authorized_keys/sysmaint"}
        ${lib.optionalString d.driverDomain ''
          ln -s ${xen}/bin/xl $out/bin/xl
          mkdir -p $out/etc/xen
          ln -s ${xenScripts} $out/etc/xen/scripts
        ''}
        ${lib.optionalString d.wprs ''
          ln -s ${pkgs.wprs}/bin/xwayland-xdg-shell ${pkgs.xwayland}/bin/Xwayland \
            ${wprsClipboard.helper}/bin/vm-clip-helper $out/bin/
          # The wprsd unit lives in the image (rootTree), the environment here:
          # no selection sync with dom0 (modules/wprs-clipboard.nix)
          ln -s ${pkgs.writeShellScript "wprsd" ''
            export WPRS_NO_SELECTION_SYNC=1
            exec ${pkgs.wprs}/bin/wprsd "$@"
          ''} $out/bin/wprsd
        ''}
      '';

      storeDisk =
        pkgs.runCommand "nox-store-${name}.squashfs"
          {
            nativeBuildInputs = [ pkgs.squashfsTools ];
            closure = pkgs.closureInfo { rootPaths = [ env ]; };
          }
          ''
            mksquashfs $(cat $closure/store-paths) $out \
              -keep-as-directory -all-root -root-mode 0755 -no-xattrs -comp zstd -mem 512M -quiet -no-progress \
              -p "nox s 0777 0 0 $(basename ${env})"
          '';

      unit = text: pkgs.writeText "unit" text;
      modules = [
        "xen-gntdev"
        "xen-gntalloc"
        "xen-evtchn"
        "squashfs"
      ]
      ++ lib.optionals d.driverDomain [
        "xen-netback"
        "xen-privcmd"
        "xenfs"
        "bridge"
      ];
      wants = [
        "nox-relay.service"
        "sshd-vchan.socket"
      ]
      ++ lib.optional d.driverDomain "xendriverdomain.service"
      ++ lib.optional (d.internalBridge != null) "nox-bridge.service";

      # Installed into the guest's root by `xen-image-setup` (only static
      # entry points into /nix/store/nox, nothing that changes with the store disk)
      rootTree = pkgs.runCommand "nox-root-${name}" { } ''
        mkdir -p $out/nix/store $out/etc/systemd/system/multi-user.target.wants $out/etc/modules-load.d
        s=$out/etc/systemd/system
        cp ${unit ''
          [Unit]
          Description=Nix store disk (nox-relay, sshd${lib.optionalString d.driverDomain ", Xen tools"})

          [Mount]
          What=/dev/xvdb
          Where=/nix/store
          Type=squashfs
          Options=ro,nodev
        ''} $s/nix-store.mount
        cp ${unit ''
          [Unit]
          Description=dom0 integration (nox-relay, sshd over vchan${lib.optionalString d.driverDomain ", xl devd"})
          Wants=${toString wants}

          [Install]
          WantedBy=multi-user.target
        ''} $s/nox.target
        ln -s ../nox.target $s/multi-user.target.wants/nox.target
        ${lib.optionalString (d.sysmaintEntry != null) ''
          # sysmaint-boot.target does not pull in multi-user.target
          mkdir -p $s/sysmaint-boot.target.wants
          ln -s ../nox.target $s/sysmaint-boot.target.wants/nox.target
        ''}
        cp ${unit ''
          [Unit]
          Description=nox-relay (guest side)
          Requires=nix-store.mount
          After=nix-store.mount systemd-modules-load.service
          StartLimitIntervalSec=0

          [Service]
          ExecStart=/nix/store/nox/bin/nox-relay --role server --peer 0 --path data/nox-relay --config /nix/store/nox/etc/nox-relay.conf
          Restart=always
          RestartSec=1
        ''} $s/nox-relay.service
        cp ${unit ''
          [Unit]
          Description=sshd setup (user, host key)
          Requires=nix-store.mount
          After=nix-store.mount

          [Service]
          Type=oneshot
          RemainAfterExit=yes
          ExecStart=/nix/store/nox/bin/nox-sshd-setup
        ''} $s/nox-sshd-setup.service
        cp ${unit ''
          [Unit]
          Description=SSH over vchan (nox-relay)
          # Not before sockets.target: the setup runs after basic.target
          DefaultDependencies=no
          Requires=nox-sshd-setup.service
          After=nox-sshd-setup.service
          Before=shutdown.target
          Conflicts=shutdown.target

          [Socket]
          ListenStream=${guestSshSocket}
          Accept=yes
          SocketMode=0600
        ''} $s/sshd-vchan.socket
        cp ${unit ''
          [Unit]
          Description=SSH over vchan (one connection)

          [Service]
          ExecStart=-/nix/store/nox/bin/sshd -i -f /nix/store/nox/etc/ssh/sshd_config
          StandardInput=socket
          StandardError=journal
        ''} $s/sshd-vchan@.service
        printf '%s\n' ${lib.escapeShellArgs modules} > $out/etc/modules-load.d/nox.conf
        ${lib.optionalString d.driverDomain ''
          # One queue per vif: with several, part of the connections of
          # multi-queue clients stalled (Workstation, xmg 2026-10-11)
          mkdir -p $out/etc/modprobe.d
          echo "options xen_netback max_queues=1" > $out/etc/modprobe.d/nox-netback.conf
          cp ${unit ''
            [Unit]
            Description=Mount /proc/xen files
            ConditionPathExists=/proc/xen
            ConditionPathExists=!/proc/xen/capabilities
            After=systemd-modules-load.service

            [Mount]
            What=xenfs
            Where=/proc/xen
            Type=xenfs
          ''} $s/proc-xen.mount
          cp ${unit ''
            [Unit]
            Description=Xen driver domain device daemon
            Requires=proc-xen.mount nix-store.mount
            After=proc-xen.mount nix-store.mount${
              lib.optionalString (d.internalBridge != null) " nox-bridge.service"
            }

            [Service]
            Type=forking
            ExecStart=/nix/store/nox/bin/xl devd
            LogsDirectory=xen
            RuntimeDirectory=xen
            StateDirectory=xen
          ''} $s/xendriverdomain.service
          mkdir -p $out/etc/xen
          ln -s /nix/store/nox/etc/xen/scripts $out/etc/xen/scripts
        ''}
        ${lib.optionalString (d.internalBridge != null) ''
          cp ${unit ''
            [Unit]
            Description=Bridge ${d.internalBridge} for the vifs this domain serves
            DefaultDependencies=no
            After=systemd-modules-load.service
            Before=network-pre.target networking.service
            Wants=network-pre.target

            [Service]
            Type=oneshot
            RemainAfterExit=yes
            ExecStart=/usr/sbin/ip link add ${d.internalBridge} type bridge stp_state 0 forward_delay 0
          ''} $s/nox-bridge.service
        ''}
        ${lib.optionalString (d.ifupdownHotplug != [ ]) ''
          mkdir -p $out/etc/network/interfaces.d
          cp ${pkgs.writeText "ifupdown-hotplug" ''
            # nox: raise again when the vif is re-attached (backend restart)
            ${lib.concatMapStrings (i: "allow-hotplug ${i}\n") d.ifupdownHotplug}''} \
            $out/etc/network/interfaces.d/31_nox-hotplug
        ''}
        ${lib.optionalString d.wprs ''
          # wprsd runs without a login (linger), like in the NixOS VMs
          mkdir -p $out/etc/systemd/user/default.target.wants $out/var/lib/systemd/linger
          cp ${unit ''
            [Unit]
            Description=wprsd instance
            # The store disk is a system mount the user manager cannot order
            # against: retry until it is there
            StartLimitIntervalSec=0

            [Service]
            Environment=PATH=/nix/store/nox/bin:/usr/local/bin:/usr/bin:/bin
            Environment=RUST_BACKTRACE=1
            ExecStart=/nix/store/nox/bin/wprsd
            Restart=always
            RestartSec=2

            [Install]
            WantedBy=default.target
          ''} $out/etc/systemd/user/wprsd.service
          ln -s ../wprsd.service $out/etc/systemd/user/default.target.wants/wprsd.service
          touch $out/var/lib/systemd/linger/user
        ''}
      '';

      xlConfig = mkXlConfig pvhgrub;
      # pvgrub2 that boots the guest's sysmaint entry instead of its default
      xlConfigSysmaint = mkXlConfig "${
        pkgs.grub2_pvhgrub_image.overrideAttrs (old: {
          name = "grub2_xen_pvh_image_sysmaint";
          env = old.env // {
            GRUB_CONFIGS = pkgs.runCommand "pvhgrub-sysmaint-configs" { } ''
              mkdir $out
              cp ${old.env.GRUB_CONFIGS}/grub-bootstrap.cfg $out/
              cat > $out/grub.cfg <<'EOF'
              # Like the stock pvhgrub config, but the guest's menu is sourced
              # (its entries stay defined) and the sysmaint entry is booted
              if search -s -f /boot/grub/grub.cfg ; then
                source /boot/grub/grub.cfg
                set default="${d.sysmaintEntry}"
                set timeout=0
              fi
              EOF
            '';
          };
        })
      }/lib/grub-xen_pvh/grub-i386-xen_pvh.bin";

      # Boots the sysmaint entry once if /run/xen-image/<name>.sysmaint exists
      start = pkgs.writeShellScript "xen-image-${name}-start" ''
        cfg=/etc/xen/image-domains/${name}/xl.cfg
        ${lib.optionalString (d.sysmaintEntry != null) ''
          if [ -e /run/xen-image/${name}.sysmaint ]; then
            ${pkgs.coreutils}/bin/rm -f /run/xen-image/${name}.sysmaint
            echo "Booting the sysmaint session" >&2
            cfg=/etc/xen/image-domains/${name}/xl-sysmaint.cfg
          fi
        ''}
        exec ${xen}/bin/xl create -F "$cfg"
      '';

      mkXlConfig =
        kernel:
        pkgs.writeText "xl.cfg" ''
          name = ${quote d.domain}
          type = "pvh"
          kernel = ${quote kernel}
          memory = ${toString d.memory}
          vcpus = ${toString d.vcpus}
          on_poweroff = "destroy"
          on_reboot = "restart"
          on_crash = "destroy"
          disk = ${
            xlList [
              "format=raw, vdev=xvda, access=rw, target=${d.image}"
              "format=raw, vdev=xvdb, access=ro, target=${storeDisk}"
            ]
          }
          vif = ${xlList (map (v: "mac=${v.mac}, bridge=${v.bridge}, backend=${v.backend}") d.vifs)}
          ${lib.optionalString d.driverDomain "driver_domain = 1"}
          ${d.extraConfig}
        '';

      # The vif backends must be up, otherwise creating the vifs fails
      preStart = pkgs.writeShellScript "xen-image-${name}-pre-start" ''
        PATH=${
          lib.makeBinPath [
            xen
            pkgs.bash
            pkgs.coreutils
            pkgs.socat
          ]
        }
        if xl domid ${lib.escapeShellArg d.domain} >/dev/null 2>&1; then
          echo "Destroying leftover Xen domain ${d.domain}" >&2
          xl destroy ${lib.escapeShellArg d.domain}
        fi
        if [ ! -f ${lib.escapeShellArg d.image} ]; then
          echo "Disk image ${d.image} is missing" >&2
          exit 1
        fi
        reachable() {
          case "$1" in
            /*) [ "$(timeout 3 socat -t 2 - "UNIX-CONNECT:$1" </dev/null 2>/dev/null | head -c 4)" = SSH- ] ;;
            *) timeout 1 bash -c "</dev/tcp/$1/22" 2>/dev/null ;;
          esac
        }
        ${lib.concatMapStrings (v: ''
          for _ in $(seq 180); do
            xl domid ${lib.escapeShellArg v.backend} >/dev/null 2>&1 &&
              reachable ${lib.escapeShellArg v.backendAddress} && break
            sleep 1
          done
        '') (lib.unique d.vifs)}
        ${lib.concatMapStrings (v: ''
          # sys-net's sshd is up before its uplink (DHCP); Tor that starts
          # without one marks its guards unreachable and does not recover
          # (Whonix-Gateway, 2026-10-12). Start anyway after 90 s.
          for i in $(seq 90); do
            be="$(xl domid ${lib.escapeShellArg v.backend} 2>/dev/null)" &&
              [ "$(xenstore-read "/local/domain/$be/data/uplink" 2>/dev/null)" = 1 ] && break
            [ "$i" = 90 ] && echo "No uplink in ${v.backend} after 90 s, starting anyway" >&2
            sleep 1
          done
        '') (lib.unique (builtins.filter (v: v.waitForUplink) d.vifs))}
      '';

      stop = pkgs.writeShellScript "xen-image-${name}-stop" ''
        PATH=${
          lib.makeBinPath [
            xen
            pkgs.coreutils
          ]
        }
        if xl domid ${lib.escapeShellArg d.domain} >/dev/null 2>&1; then
          timeout 60 xl shutdown -w ${lib.escapeShellArg d.domain} ||
            xl destroy ${lib.escapeShellArg d.domain}
          for _ in $(seq 20); do
            xl domid ${lib.escapeShellArg d.domain} >/dev/null 2>&1 || break
            sleep 0.5
          done
        fi
      '';
    in
    {
      inherit
        storeDisk
        rootTree
        xlConfig
        xlConfigSysmaint
        start
        preStart
        stop
        ;
      sysmaint = d.sysmaintEntry != null;
    };

  guests = lib.mapAttrs mkGuest cfg.domains;

  # `xen-image-setup <name>`: install the units into the stopped image
  setup = pkgs.writeShellScriptBin "xen-image-setup" ''
    set -euo pipefail
    PATH=${
      lib.makeBinPath [
        pkgs.e2fsprogs
        pkgs.util-linux
        pkgs.jq
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        config.systemd.package
      ]
    }
    case "''${1:-}" in
      ${lib.concatStrings (
        lib.mapAttrsToList (name: d: ''
          ${name}) image=${lib.escapeShellArg d.image} part=${toString d.rootPartition} tree=${guests.${name}.rootTree} ;;
        '') cfg.domains
      )}
      *)
        echo "usage: xen-image-setup <${lib.concatStringsSep "|" (lib.attrNames cfg.domains)}>" >&2
        exit 2
        ;;
    esac
    if systemctl is-active --quiet "xen-image@$1"; then
      echo "xen-image@$1 is running; stop it first" >&2
      exit 1
    fi
    start="$(sfdisk -J "$image" | jq -r --argjson n "$part" '.partitiontable.partitions[$n - 1].start')"
    fs="$image?offset=$((start * 512))"
    state="$(debugfs -R stats "$fs" 2>/dev/null | grep '^Filesystem state:' || true)"
    if [[ "$state" != *" clean" ]]; then
      echo "Root file system not cleanly unmounted ($state); boot and shut down the guest first" >&2
      exit 1
    fi
    exists() { debugfs -R "stat $1" "$fs" 2>/dev/null | grep -q '^Inode:'; }
    cmds="$(mktemp)"
    trap 'rm -f "$cmds"' EXIT
    cd "$tree"
    while IFS= read -r p; do
      d="''${p#.}"
      if [ -L "$p" ]; then
        exists "$d" && echo "rm $d"
        echo "symlink $d $(readlink "$p")"
      elif [ -d "$p" ]; then
        exists "$d" && continue
        echo "mkdir $d"
        echo "sif $d mode 040755"
      else
        exists "$d" && echo "rm $d"
        echo "write $p $d"
        if [ -x "$p" ]; then echo "sif $d mode 0100755"; else echo "sif $d mode 0100644"; fi
      fi
      echo "sif $d uid 0"
      echo "sif $d gid 0"
    done < <(find . -mindepth 1 | sort) >"$cmds"
    # debugfs echoes every command; show only what went wrong
    debugfs -w -f "$cmds" "$fs" 2>&1 | grep -vE '^(debugfs( [0-9]|: )|Allocated inode|$)' || true
    echo "Installed $(grep -c -E '^(write|symlink|mkdir) ' "$cmds") entries from $tree into $image (partition $part)"
  '';
in
{
  options.services.xen-image-domains = {
    domains = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule domainOpts);
      default = { };
      description = "Xen domains booted from upstream disk images.";
    };
  };

  config = lib.mkIf (cfg.domains != { }) {
    environment.systemPackages = [ setup ];

    environment.etc = lib.mkMerge (
      lib.mapAttrsToList (
        name: g:
        {
          "xen/image-domains/${name}/xl.cfg".source = g.xlConfig;
          "xen/image-domains/${name}/pre-start".source = g.preStart;
          "xen/image-domains/${name}/stop".source = g.stop;
          "xen/image-domains/${name}/start".source = g.start;
        }
        // lib.optionalAttrs g.sysmaint {
          "xen/image-domains/${name}/xl-sysmaint.cfg".source = g.xlConfigSysmaint;
        }
      ) guests
    );

    systemd.services = {
      "xen-image@" = {
        description = "Xen image domain %i";
        after = [
          "xenstored.service"
          "xenconsoled.service"
        ];
        requires = [ "xenstored.service" ];
        serviceConfig = {
          Type = "simple";
          ExecStartPre = "/etc/xen/image-domains/%i/pre-start";
          ExecStart = "/etc/xen/image-domains/%i/start";
          ExecStop = "/etc/xen/image-domains/%i/stop";
          TimeoutStartSec = 300;
          TimeoutStopSec = 90;
        };
      };
    }
    // lib.mapAttrs' (
      name: _:
      lib.nameValuePair "xen-image@${name}" {
        overrideStrategy = "asDropin";
        wantedBy = [ "multi-user.target" ];
      }
    ) (lib.filterAttrs (_: d: d.autostart) cfg.domains);

    # dom0's side of the relay: SSH (vm-run -c, ssh <name>-vm) plus extras
    services.nox-relay.host.guests = lib.mapAttrs (name: d: {
      inherit (d) domain;
      serve = d.relay.host.serve // lib.optionalAttrs d.wprs { pulse = "/run/user/1000/pulse/native"; };
      listen =
        d.relay.host.listen
        // {
          ssh = {
            path = "/run/nox-relay/${name}-ssh.sock";
            owner = "1000:100";
          };
        }
        // lib.optionalAttrs d.wprs {
          # dom0's wprsc (vm-gui)
          wprs = {
            path = "/run/nox-relay/${name}-wprs.sock";
            owner = "1000:100";
          };
        };
    }) cfg.domains;

    # vifs come back after a backend restart
    services.xen-links.extraLinks = lib.concatLists (
      lib.mapAttrsToList (
        _: d:
        map (v: {
          inherit (d) domain;
          inherit (v)
            mac
            bridge
            backend
            backendAddress
            ;
        }) d.vifs
      ) cfg.domains
    );
  };
}
