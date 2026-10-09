# Guest side of nox-relay (v2.8.4, NoX flake input): sockets from dom0 over a
# vchan instead of SSH forwards. Xen VMs only, at the paths the SSH forwards
# used:
# - GitHub agent (registry `allowGitHubAgent`)
# - filtered session bus, notifications + tray (`enableHostDbusForward`)
# - SSH (VMs with sshd): dom0's ssh reaches sshd -i (socket-activated per
#   connection) instead of the admin network (stage B, ProxyCommand in
#   home/ssh.nix); stage B2 drops the admin interface (except sys-net)
# - wprs (VMs with wprsd, vms/modules/wprs.nix): dom0's wprsc reaches wprsd,
#   apps get dom0's pulse socket at /tmp/wprs-pulse (`vm-gui` in dom0)
# - RPC (stage C, app VMs): `vm-copy`, incoming files in ~/Incoming/<source>
# dom0 side: machines/hp/xen.nix
{
  lib,
  config,
  options,
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
  imports = [
    inputs.nox.nixosModules.relay
    inputs.nox.nixosModules.rpc
  ];

  config = lib.mkIf (config.microvm.hypervisor == "xen" && (githubAgent || dbus || wprs || ssh)) (
    lib.mkMerge [
      {
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
      }

      (lib.mkIf ssh {
        # One sshd -i per connection on the relay's socket (same config and
        # host keys as the network sshd)
        systemd.sockets.sshd-vchan = {
          description = "SSH over vchan (nox-relay)";
          wantedBy = [ "sockets.target" ];
          socketConfig = {
            ListenStream = sshSocket;
            Accept = true;
            SocketMode = "0600";
          };
        };
        systemd.services."sshd-vchan@" = {
          description = "SSH over vchan (one connection)";
          serviceConfig = {
            ExecStart = "-${config.services.openssh.package}/bin/sshd -i -f /etc/ssh/sshd_config";
            StandardInput = "socket";
            StandardError = "journal";
          };
        };

        # Stage B2: dom0 reaches the guest over vchan only, no sshd on the
        # network. sys-net keeps its admin link: dom0's internet in the test
        # phase goes through it (xen-migration.md, SSH target picture)
        services.openssh.openFirewall = lib.mkIf (vmName != "sys-net") (lib.mkDefault false);
      })

      # RPC (stage C): app VMs call (`vm-copy <vm> <files>`) and receive
      # (~/Incoming/<source>); driver domains and the builder take no part
      (lib.mkIf (
        !builtins.elem vmName [
          "sys-net"
          "sys-usb"
          "builder"
        ]
      ) { services.nox-rpc.guest.enable = true; })

      # ... and no admin interface (only for VMs that use net-config)
      (lib.optionalAttrs (options.services ? net-config) {
        services.net-config.adminInterface = lib.mkIf ssh (lib.mkDefault (vmName == "sys-net"));
      })
    ]
  );
}
