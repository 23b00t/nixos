# Xen dom0 test setup for hp: replaces the KVM stack (libvirt) from
# common-configuration.nix. Based on the former `xen` branch.
# MicroVMs run as Xen PVH domUs via the microvm.nix fork (hypervisor = "xen").
{ lib, ... }:
{
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
