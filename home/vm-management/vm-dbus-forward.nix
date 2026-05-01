{ pkgs, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  dbusForwardHosts = vmRegistry.dbusForwardParticipants or [ ];
  vmUser = "user";
  hostDbusSocket = "/run/user/1000/vm-session-bus.sock";
  remoteDbusSocket = "/tmp/ssh_dbus.sock";
  sshVmOptions = builtins.concatStringsSep " " [
    "-o BatchMode=yes"
    "-o ExitOnForwardFailure=yes"
    "-o ServerAliveInterval=30"
    "-o ServerAliveCountMax=3"
    "-o ControlMaster=no"
    "-o IdentitiesOnly=yes"
    "-o StrictHostKeyChecking=no"
    "-o UserKnownHostsFile=/dev/null"
    "-o IdentityAgent=none"
    "-o ForwardAgent=no"
    "-o ConnectTimeout=5"
    "-o StreamLocalBindUnlink=yes"
  ];
in
{
  systemd.user.services = builtins.listToAttrs (
    map (
      vm: {
        name = "vm-dbus-forward@${vm.name}";
        value = {
          Unit = {
            Description = "Persistent DBus remote-forward tunnel for ${vm.name}-vm";
            After = [ "default.target" "vm-session-bus-proxy.service" ];
            Wants = [ "default.target" "vm-session-bus-proxy.service" ];
          };
          Service = {
            Type = "simple";
            Restart = "always";
            RestartSec = 2;
            ExecStartPre = "${pkgs.coreutils}/bin/test -S %t/vm-session-bus.sock";
            ExecStart = "${pkgs.openssh}/bin/ssh -N ${sshVmOptions} -i %h/.ssh/${vm.name}-vm -R ${remoteDbusSocket}:${hostDbusSocket} ${vmUser}@${vm.ip}";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      }
    ) dbusForwardHosts
  );
}
