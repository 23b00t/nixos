# Guest side of nox-relay (v2.8.4, NoX flake input): sockets from dom0 over a
# vchan instead of SSH forwards. Xen VMs only, at the paths the SSH forwards
# used:
# - GitHub agent (registry `allowGitHubAgent`)
# - filtered session bus, notifications + tray (`enableHostDbusForward`)
# - SSH (VMs with sshd): dom0's ssh reaches sshd -i (socket-activated per
#   connection) instead of the admin network (stage B, ProxyCommand in
#   home/ssh.nix)
# - wprs (VMs with wprsd, vms/modules/wprs.nix): dom0's wprsc reaches wprsd,
#   apps get dom0's pulse socket at /tmp/wprs-pulse (`vm-gui` in dom0)
# dom0 side: machines/hp/xen.nix
{
  lib,
  config,
  inputs,
  ...
}:
let
  vmRegistry = import ../registry.nix;
  vmName = lib.removeSuffix "-vm" (config.networking.hostName or "");
  vm = vmRegistry.byName.${vmName} or { };
  githubAgent = vm.allowGitHubAgent or false;
  dbus = vm != { } && (vm.enableHostDbusForward or true);
  wprs = config.systemd.user.services ? wprsd;
  ssh = config.services.openssh.enable;
  sshSocket = "/run/sshd-vchan.sock";
  # uid/gid of `user` in the VMs
  owner = "1000:100";
in
{
  imports = [ inputs.nox.nixosModules.relay ];

  config = lib.mkIf (config.microvm.hypervisor == "xen" && (githubAgent || dbus || wprs || ssh)) {
    services.nox-relay.guest = {
      enable = true;
      listen =
        lib.optionalAttrs githubAgent {
          github-agent = {
            path = "/tmp/ssh-github-agent.sock";
            inherit owner;
          };
        }
        // lib.optionalAttrs dbus {
          dbus = {
            path = "/tmp/ssh_dbus.sock";
            inherit owner;
          };
        }
        // lib.optionalAttrs wprs {
          pulse = {
            path = "/tmp/wprs-pulse";
            inherit owner;
          };
        };
      serve =
        lib.optionalAttrs wprs { wprs = "/run/user/1000/wprs.sock"; }
        // lib.optionalAttrs ssh { ssh = sshSocket; };
    };

    # wprsd has to run without an SSH login (GUI over vchan)
    users.users.user.linger = lib.mkIf wprs true;

    # One sshd -i per connection on the relay's socket (same config and
    # host keys as the network sshd)
    systemd.sockets.sshd-vchan = lib.mkIf ssh {
      description = "SSH over vchan (nox-relay)";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = sshSocket;
        Accept = true;
        SocketMode = "0600";
      };
    };
    systemd.services."sshd-vchan@" = lib.mkIf ssh {
      description = "SSH over vchan (one connection)";
      serviceConfig = {
        ExecStart = "-${config.services.openssh.package}/bin/sshd -i -f /etc/ssh/sshd_config";
        StandardInput = "socket";
        StandardError = "journal";
      };
    };
  };
}
