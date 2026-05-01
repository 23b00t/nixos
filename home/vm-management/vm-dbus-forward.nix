{ pkgs, lib, ... }:
let
  vmRegistry = import ../../vms/registry.nix;
  dbusForwardHosts = vmRegistry.dbusForwardParticipants or [ ];
  vmUser = "user";
  hostDbusSocket = "/run/user/1000/vm-session-bus.sock";
  remoteDbusSocket = "/tmp/ssh_dbus.sock";
  remoteDbusAddress = "unix:path=${remoteDbusSocket}";
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
  ];
  remoteDbusRefreshCommand = builtins.concatStringsSep " " [
    "current_dbus=\"$(${pkgs.systemd}/bin/systemctl --user show-environment 2>/dev/null | ${pkgs.gnugrep}/bin/grep '^DBUS_SESSION_BUS_ADDRESS=' || true)\";"
    "${pkgs.systemd}/bin/systemctl --user set-environment DBUS_SESSION_BUS_ADDRESS=${remoteDbusAddress} >/dev/null 2>&1 || true;"
    "if [ \"$current_dbus\" != \"DBUS_SESSION_BUS_ADDRESS=${remoteDbusAddress}\" ]; then"
    "${pkgs.systemd}/bin/systemctl --user try-restart wprsd.service >/dev/null 2>&1 || true;"
    "fi"
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
            # The VM can be up before the reverse DBus tunnel exists, so refresh wprsd
            # once when the remote user systemd environment first learns the DBus socket.
            # Avoid restarting on every later SSH tunnel reconnect.
            ExecStartPost = "${pkgs.openssh}/bin/ssh ${sshVmOptions} -i %h/.ssh/${vm.name}-vm ${vmUser}@${vm.ip} ${lib.escapeShellArg remoteDbusRefreshCommand}";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      }
    ) dbusForwardHosts
  );
}
