# USB/IP client (v2.6): attaches the USB devices this VM owns in the registry
# from sys-usb. The link interface is hot-plugged by dom0 (modules/xen-usb.nix)
# once both domains run, so this VM starts without sys-usb. Active for Xen
# VMs that own exported devices (vms/usb-links.nix).
{
  lib,
  pkgs,
  config,
  ...
}:
let
  vmRegistry = import ../registry.nix;
  links = import ../usb-links.nix { inherit lib vmRegistry; };
  vmName = lib.removeSuffix "-vm" (config.networking.hostName or "");
  devices = if vmRegistry.byName ? ${vmName} then links.devicesFor vmName else [ ];
  enable = devices != [ ] && config.microvm.hypervisor == "xen";
  usbip = config.boot.kernelPackages.usbip;

  # `usbip list`/`usbip port` show devices as "(vvvv:pppp)"
  attach = pkgs.writeShellScript "usbip-attach" ''
    PATH=${
      lib.makeBinPath [
        usbip
        pkgs.gawk
        pkgs.gnugrep
        pkgs.coreutils
      ]
    }
    while true; do
      for vp in ${lib.concatMapStringsSep " " (d: "${d.vendorId}:${d.productId}") devices}; do
        if ! usbip port 2>/dev/null | grep -qF "($vp)"; then
          busid="$(usbip list -r ${links.serverAddress} 2>/dev/null \
            | awk -v vp="($vp)" 'index($0, vp) && $1 ~ /:$/ { sub(":$", "", $1); print $1; exit }')"
          if [ -n "$busid" ] && usbip attach -r ${links.serverAddress} -b "$busid"; then
            echo "attached $vp (busid $busid)"
          fi
        fi
      done
      sleep 5
    done
  '';
in
{
  config = lib.mkIf enable {
    boot.kernelModules = [ "vhci-hcd" ];

    systemd.network.networks."22-usbip-link" = {
      matchConfig.MACAddress = links.macOf vmName;
      address = [ "${links.addressOf vmName}/${toString links.prefixLength}" ];
      networkConfig.ConfigureWithoutCarrier = true;
      linkConfig.RequiredForOnline = "no";
    };

    systemd.services.usbip-attach = {
      description = "Attach this VM's USB devices from sys-usb (USB/IP)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = attach;
        Restart = "always";
        RestartSec = 5;
      };
    };

    environment.systemPackages = [ usbip ];
  };
}
