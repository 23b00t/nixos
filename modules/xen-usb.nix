# dom0 side of sys-usb (v2.6):
# - input proxy: input devices owned by `host` (registry) come back from
#   sys-usb over SSH as raw events (cat) into a filtering uinput receiver
# - USB/IP links: kept connected by modules/xen-links.nix
# - fallback: if sys-usb is not reachable 120 s after its start, the USB
#   controllers go back to dom0 (needed on the XMG for keyboard/mouse)
# - sys-usb-rescue: the same by hand
{
  lib,
  pkgs,
  config,
  vmRegistry,
  ...
}:
let
  cfg = config.services.xen-usb;
  links = import ../vms/usb-links.nix { inherit lib vmRegistry; };
  usbPciPaths = vmRegistry.hardware.pci.devicePaths.usb or [ ];
  xen = config.virtualisation.xen.package;
  sshOpts = "-o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o LogLevel=ERROR";

  # Reads raw struct input_event from stdin (sys-usb: cat /dev/input/eventN)
  # and replays it on a uinput device whose capabilities are fixed here, not
  # taken from sys-usb: keyboard keys and mouse buttons/axes only, without
  # power/sleep/wakeup/suspend/rfkill (logind, rfkill) and SysRq (kernel).
  # Everything else (other types, codes, key repeats) is dropped.
  inputRecv = pkgs.writeCBin "xen-input-recv" ''
    #include <fcntl.h>
    #include <linux/uinput.h>
    #include <stdio.h>
    #include <string.h>
    #include <sys/ioctl.h>
    #include <unistd.h>

    static const int rels[] = { REL_X, REL_Y, REL_HWHEEL, REL_WHEEL,
                                REL_WHEEL_HI_RES, REL_HWHEEL_HI_RES };

    static int key_allowed(int code)
    {
      if (code >= BTN_LEFT && code <= BTN_TASK)
        return 1;
      if (code < 1 || code > 255)
        return 0;
      switch (code) {
      case KEY_SYSRQ: case KEY_POWER: case KEY_SLEEP: case KEY_WAKEUP:
      case KEY_SUSPEND: case KEY_RFKILL:
        return 0;
      }
      return 1;
    }

    static int rel_allowed(int code)
    {
      for (size_t i = 0; i < sizeof(rels) / sizeof(rels[0]); i++)
        if (rels[i] == code)
          return 1;
      return 0;
    }

    static int emit(int fd, int type, int code, int value)
    {
      struct input_event ev;
      memset(&ev, 0, sizeof(ev));
      ev.type = type;
      ev.code = code;
      ev.value = value;
      return write(fd, &ev, sizeof(ev)) == sizeof(ev) ? 0 : -1;
    }

    int main(int argc, char **argv)
    {
      struct uinput_setup setup;
      struct input_event ev;
      int fd, pending = 0;

      if (argc != 2) {
        fprintf(stderr, "usage: xen-input-recv <name>\n");
        return 2;
      }
      fd = open("/dev/uinput", O_WRONLY | O_CLOEXEC);
      if (fd < 0) {
        perror("open /dev/uinput");
        return 1;
      }
      ioctl(fd, UI_SET_EVBIT, EV_SYN);
      ioctl(fd, UI_SET_EVBIT, EV_KEY);
      ioctl(fd, UI_SET_EVBIT, EV_REL);
      for (int code = 0; code <= BTN_TASK; code++)
        if (key_allowed(code))
          ioctl(fd, UI_SET_KEYBIT, code);
      for (size_t i = 0; i < sizeof(rels) / sizeof(rels[0]); i++)
        ioctl(fd, UI_SET_RELBIT, rels[i]);

      memset(&setup, 0, sizeof(setup));
      setup.id.bustype = BUS_VIRTUAL;
      snprintf(setup.name, UINPUT_MAX_NAME_SIZE, "xen-input-proxy %s", argv[1]);
      if (ioctl(fd, UI_DEV_SETUP, &setup) < 0 || ioctl(fd, UI_DEV_CREATE) < 0) {
        perror("uinput setup");
        return 1;
      }

      while (fread(&ev, sizeof(ev), 1, stdin) == 1) {
        int ok = 0;
        if (ev.type == EV_KEY)
          ok = key_allowed(ev.code) && (ev.value == 0 || ev.value == 1);
        else if (ev.type == EV_REL)
          ok = rel_allowed(ev.code);
        else if (ev.type == EV_SYN && ev.code == SYN_REPORT && pending) {
          if (emit(fd, EV_SYN, SYN_REPORT, 0) < 0)
            break;
          pending = 0;
        }
        if (ok) {
          if (emit(fd, ev.type, ev.code, ev.value) < 0)
            break;
          pending = 1;
        }
      }

      ioctl(fd, UI_DEV_DESTROY);
      close(fd);
      return 0;
    }
  '';

  inputProxy = pkgs.writeShellScript "xen-input-proxy" ''
    PATH=${
      lib.makeBinPath [
        pkgs.openssh
        pkgs.coreutils
      ]
    }
    declare -A pids
    while true; do
      if devs="$(ssh ${sshOpts} ${links.adminAddress} 'ls /dev/input-proxy 2>/dev/null')"; then
        for d in $devs; do
          # Names come from sys-usb: only <vendor>-<product>-event<N>
          [[ "$d" =~ ^[0-9a-f]{4}-[0-9a-f]{4}-event[0-9]+$ ]] || continue
          if [ -z "''${pids[$d]:-}" ] || ! kill -0 "''${pids[$d]}" 2>/dev/null; then
            echo "forwarding $d"
            ssh ${sshOpts} ${links.adminAddress} "cat /dev/input-proxy/$d" \
              | ${inputRecv}/bin/xen-input-recv "$d" &
            pids[$d]=$!
          fi
        done
      fi
      sleep 3
    done
  '';

  # Give the USB controllers back to dom0
  releaseControllers = ''
    if xl domid ${links.domain} >/dev/null 2>&1; then
      xl destroy ${links.domain} || true
    fi
    ${lib.concatMapStrings (path: ''
      xl pci-assignable-remove -r ${path} || true
    '') usbPciPaths}
  '';

  sysUsbRescue = pkgs.writeShellScriptBin "sys-usb-rescue" ''
    set -u
    sudo systemctl stop microvm@sys-usb
    sudo ${pkgs.writeShellScript "sys-usb-release" ''
      PATH=${lib.makeBinPath [ xen ]}
      ${releaseControllers}
    ''}
    echo "USB controllers are back in dom0."
    echo "Start sys-usb again later with: sudo systemctl start microvm@sys-usb"
  '';
in
{
  options.services.xen-usb = {
    enable = lib.mkEnableOption "dom0 side of sys-usb (input proxy, fallback)";

    user = lib.mkOption {
      type = lib.types.str;
      default = "nx";
      description = "dom0 user whose SSH setup reaches sys-usb; runs the input proxy.";
    };

    fallbackTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
      description = "Seconds sys-usb gets to become reachable before dom0 takes the USB controllers back.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.uinput.enable = true;

    environment.systemPackages = [ sysUsbRescue ];

    systemd.services = {
      xen-input-proxy = {
        description = "Forward input devices from sys-usb to dom0";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = inputProxy;
          User = cfg.user;
          SupplementaryGroups = [ "uinput" ];
          Restart = "always";
          RestartSec = 5;
        };
      };

      sys-usb-fallback = {
        description = "Take the USB controllers back if sys-usb does not come up";
        wantedBy = [ "microvm@sys-usb.service" ];
        after = [ "microvm@sys-usb.service" ];
        path = [
          xen
          pkgs.coreutils
          pkgs.bash
          pkgs.systemd
        ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = cfg.fallbackTimeout + 60;
        };
        script = ''
          for _ in $(seq ${toString cfg.fallbackTimeout}); do
            if timeout 1 bash -c '</dev/tcp/${links.adminAddress}/22' 2>/dev/null; then
              exit 0
            fi
            sleep 1
          done
          echo "sys-usb not reachable after ${toString cfg.fallbackTimeout} s, giving the USB controllers back to dom0"
          systemctl stop --no-block microvm@sys-usb.service
          sleep 5
          ${releaseControllers}
        '';
      };
    };
  };
}
