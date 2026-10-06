# Xen dom0 test setup for hp: replaces the KVM stack (libvirt) from
# common-configuration.nix. Based on the former `xen` branch.
# MicroVMs run as Xen PVH domUs via the microvm.nix fork (hypervisor = "xen").
{
  lib,
  pkgs,
  config,
  vmRegistry,
  ...
}:
let
  builderIp = vmRegistry.byName.builder.ip;
in
{
  imports = [
    ../../modules/xen-memory.nix
    ../../modules/dom0-update.nix
  ];

  virtualisation.xen = {
    enable = true;
    # Test phase: guest consoles are logged to /var/log/xen/console/
    trace = true;
    boot = {
      builderVerbosity = "info"; # report which Xen boot entries were created
      params = [ "dom0=pvh" ];
    };
    dom0Resources = {
      # 4096 is too small to evaluate this flake on dom0 (swap thrashing)
      memory = 8192;
      maxVCPUs = 4;
    };
  };

  # dom0 keeps its memory: xl must not take it to start guests. The RAM
  # balancer only moves memory between ballooning MicroVMs.
  environment.etc."xen/xl.conf".source = lib.mkForce (
    pkgs.runCommand "xl.conf" { } ''
      cat ${config.virtualisation.xen.package}/etc/xen/xl.conf > $out
      echo 'autoballoon="off"' >> $out
    ''
  );

  services.xen-memory-balancer.enable = true;

  # dom0 pulls its system from the builder VM (v2.4): `dom0-update [--switch]`
  services.dom0-update.enable = true;

  # Transitional until sys-net exists (v2.5): the builder (and only the
  # builder) reaches the internet through NAT on dom0's WLAN
  networking = {
    nat = {
      enable = true;
      externalInterface = "wlo1";
      internalIPs = [ "${builderIp}/32" ];
    };
    # NAT turns on forwarding for every interface: drop everything else that
    # goes from the VM bridge to the WLAN
    firewall = {
      extraCommands = ''
        iptables -w -N builder-only-fwd 2>/dev/null || true
        iptables -w -F builder-only-fwd
        iptables -w -D FORWARD -j builder-only-fwd 2>/dev/null || true
        iptables -w -I FORWARD -j builder-only-fwd
        iptables -w -A builder-only-fwd -i vm-internal -o wlo1 ! -s ${builderIp} -j DROP
      '';
      extraStopCommands = ''
        iptables -w -D FORWARD -j builder-only-fwd 2>/dev/null || true
      '';
    };
  };

  # PVH dom0 is the target. On hp the I2C touchpad only works with a PV dom0
  # (see README "Known hardware issues"); a PV specialisation doubled the
  # eval memory, so it was removed again.

  # Only the VMs switched to Xen can run; KVM-based ones would fail on start
  microvm.autostart = lib.mkForce [
    "vault"
    "nvim"
    "coding"
  ];

  # Xen creates vifs as vif<domid>.<n> before renaming them to vm<N>
  networking.networkmanager.unmanaged = [ "interface-name:vif*" ];

  # No KVM under Xen: no libvirt
  virtualisation.libvirtd.enable = lib.mkForce false;
  programs.virt-manager.enable = lib.mkForce false;

  systemd = {
    services = {
      # The microvm@ services manage the domains. xendomains (no /etc/xen/auto)
      # falls back to `xl shutdown --all --wait` in parallel and hangs until
      # systemd's stop timeout (90 s) on every dom0 shutdown.
      xendomains.enable = false;
      libvirt-bridge-networks.enable = false;
      retrigger-vm11-tor-udev.enable = false;
    };

    # Keep vm-internal (host 10.0.0.254 <-> VMs), but there is no sys-net to
    # route through; the host uses NetworkManager directly
    network.networks."32-vm-internal".routes = lib.mkForce [ ];
  };
}
