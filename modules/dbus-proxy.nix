{ pkgs, ... }:

{
  systemd.user.services.vm-session-bus-proxy = {
    description = "Filtered host D-Bus proxy for VMs";
    wantedBy = [ "default.target" ];

    script = ''
      ${pkgs.coreutils}/bin/rm -f "$XDG_RUNTIME_DIR/vm-session-bus.sock"

      exec ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
        "unix:path=$XDG_RUNTIME_DIR/bus" \
        "$XDG_RUNTIME_DIR/vm-session-bus.sock" \
        --filter \
        --talk=org.freedesktop.Notifications \
        --talk=org.kde.StatusNotifierWatcher \
        --talk=org.freedesktop.StatusNotifierWatcher \
        --own=org.kde.StatusNotifierItem-* \
        --own=org.freedesktop.StatusNotifierItem-*
    '';

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
