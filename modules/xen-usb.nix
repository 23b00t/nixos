# dom0 side of sys-usb (v2.6):
# - input proxy: input devices owned by `host` (registry) come back from
#   sys-usb over SSH (netevent cat | netevent create via uinput)
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

  inputProxy = pkgs.writeShellScript "xen-input-proxy" ''
    PATH=${
      lib.makeBinPath [
        pkgs.openssh
        pkgs.netevent
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
            ssh ${sshOpts} ${links.adminAddress} "netevent cat /dev/input-proxy/$d" \
              | netevent create --duplicates=replace &
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
