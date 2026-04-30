{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  dbusForwardHosts = vmRegistry.dbusForwardParticipants or [ ];
  vmNames = builtins.concatStringsSep " " (map (vm: vm.name) dbusForwardHosts);
in
{
  systemd.user.services = builtins.listToAttrs (
    map (
      vm: {
        name = "vm-dbus-forward@${vm.name}";
        value = {
          Unit = {
            Description = "Persistent DBus remote-forward tunnel for ${vm.name}-vm";
            After = [ "default.target" ];
            Wants = [ "default.target" ];
          };
          Service = {
            Type = "simple";
            Restart = "always";
            RestartSec = 2;
            ExecStart = "${pkgs.openssh}/bin/ssh -N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ControlMaster=no -o IdentityAgent=none -o ForwardAgent=no -i %h/.ssh/${vm.name}-vm -R /tmp/ssh_dbus.sock:/run/user/1000/vm-session-bus.sock user@${vm.ip}";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      }
    ) dbusForwardHosts
  );
}
