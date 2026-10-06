{
  lib,
  config,
  ...
}:

with lib;

let
  cfg = config.services.net-config;
  vmRegistry = import ../registry.nix;
  hostName = config.networking.hostName or "";
  vmName = removeSuffix "-vm" hostName;
  currentVm = vmRegistry.byName.${vmName} or { };

  defaultTapId = if cfg.index == null then null else "vm${toString cfg.index}";
  effectiveTapId = if cfg.tapId != null then cfg.tapId else defaultTapId;
  effectiveAddress4 =
    if cfg.address4 != null then
      cfg.address4
    else if cfg.index != null then
      "10.0.0.${toString cfg.index}/24"
    else
      null;
  effectiveGateway4 = cfg.gateway4;
  needsOnLinkGatewayRoute = effectiveAddress4 != null && hasSuffix "/32" effectiveAddress4;

  indexHex = fixedWidthString 2 "0" (toLower (toHexString cfg.index));

  hostPkgs = config.microvm.vmHostPackages;
in
{
  options.services.net-config = {
    enable = mkEnableOption "Enable the VM network configuration module";

    index = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Legacy VM index used to derive tap id and IPv4 address.";
    };

    tapId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional explicit host-side tap id.";
    };

    mac = mkOption {
      type = types.str;
      description = "MAC address for the guest interface.";
    };

    interfaceName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional stable guest interface name.";
    };

    address4 = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional explicit IPv4 address with prefix length.";
    };

    gateway4 = mkOption {
      type = types.nullOr types.str;
      # With an uplink, the admin network has no default route
      default = if cfg.uplink.enable then null else "10.0.0.253";
      defaultText = literalExpression ''if uplink.enable then null else "10.0.0.253"'';
      description = "IPv4 default gateway. Set to null to disable.";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
        "2620:fe::9"
      ];
      description = "DNS servers for the guest.";
    };

    # Xen (v2.5): second interface served by sys-net (driver domain), the VM's
    # default route. The admin interface above stays for dom0 only.
    uplink = {
      enable = mkOption {
        type = types.bool;
        default = (currentVm.nat or false) && config.microvm.hypervisor == "xen";
        defaultText = literalExpression ''registry `nat` && microvm.hypervisor == "xen"'';
        description = "Give the VM an uplink interface with sys-net as backend.";
      };

      mac = mkOption {
        type = types.str;
        default = "00:00:00:00:01:${indexHex}";
        defaultText = literalExpression ''"00:00:00:00:01:<index as hex>"'';
        description = "MAC address of the uplink interface.";
      };

      address4 = mkOption {
        type = types.str;
        default = "10.1.0.${toString cfg.index}/24";
        defaultText = literalExpression ''"10.1.0.<index>/24"'';
        description = "IPv4 address of the uplink interface.";
      };

      gateway4 = mkOption {
        type = types.str;
        default = "10.1.0.254";
        description = "Default gateway on the uplink (sys-net).";
      };

      backend = mkOption {
        type = types.str;
        default = "sys-net-vm";
        description = "Xen domain serving the uplink (driver domain).";
      };

      backendAddress = mkOption {
        type = types.str;
        default = "10.0.0.253";
        description = "Admin address of the backend domain, used to wait for it before starting.";
      };

      bridge = mkOption {
        type = types.str;
        default = "vm-uplink";
        description = "Bridge in the backend domain.";
      };
    };
  };

  config = mkIf cfg.enable {
    networking.useNetworkd = true;

    assertions = [
      {
        assertion = effectiveAddress4 != null;
        message = "services.net-config requires either index or address4.";
      }
      {
        assertion = !cfg.uplink.enable || (cfg.index != null && config.microvm.hypervisor == "xen");
        message = "services.net-config.uplink needs an index and microvm.hypervisor = \"xen\".";
      }
    ];

    microvm = {
      interfaces =
        optional (effectiveTapId != null) {
          id = effectiveTapId;
          type = "tap";
          inherit (cfg) mac;
        }
        ++ optional cfg.uplink.enable {
          id = "uplink";
          type = "bridge";
          inherit (cfg.uplink) mac bridge;
        };

      xen.interfaceBackends = mkIf cfg.uplink.enable {
        uplink = cfg.uplink.backend;
      };

      # Runs in dom0 before the domain is created: the uplink backend (xl devd
      # in sys-net) must be up, otherwise creating the vif fails. sys-net's
      # sshd comes up with its other services, so it is a usable readiness signal.
      preStart = mkIf cfg.uplink.enable ''
        for _ in $(${hostPkgs.coreutils}/bin/seq 180); do
          if ${config.microvm.xen.package}/bin/xl domid ${cfg.uplink.backend} >/dev/null 2>&1 \
            && ${hostPkgs.coreutils}/bin/timeout 1 ${hostPkgs.bash}/bin/bash -c \
              '</dev/tcp/${cfg.uplink.backendAddress}/22' 2>/dev/null; then
            break
          fi
          ${hostPkgs.coreutils}/bin/sleep 1
        done
      '';
    };

    systemd.network.links = mkIf (cfg.interfaceName != null) {
      "10-net-config-link" = {
        matchConfig.MACAddress = cfg.mac;
        linkConfig.Name = cfg.interfaceName;
      };
    };

    systemd.network.networks = {
      "20-net-config" = {
        matchConfig.MACAddress = cfg.mac;
        address = [ effectiveAddress4 ];
        routes =
          optional (effectiveGateway4 != null && needsOnLinkGatewayRoute) {
            Destination = "${effectiveGateway4}/32";
            Scope = "link";
          }
          ++ optional (effectiveGateway4 != null) {
            Destination = "0.0.0.0/0";
            Gateway = effectiveGateway4;
          };
        networkConfig.DNS = mkIf (!cfg.uplink.enable) cfg.dns;
      };

      "21-net-config-uplink" = mkIf cfg.uplink.enable {
        matchConfig.MACAddress = cfg.uplink.mac;
        address = [ cfg.uplink.address4 ];
        routes = [
          {
            Destination = "0.0.0.0/0";
            Gateway = cfg.uplink.gateway4;
          }
        ];
        networkConfig.DNS = cfg.dns;
      };
    };
  };
}
