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
        --log \
        --see=org.freedesktop.Notifications \
        --talk=org.freedesktop.Notifications \
        --see=org.kde.StatusNotifierWatcher \
        --talk=org.kde.StatusNotifierWatcher \
        --see=org.freedesktop.StatusNotifierWatcher \
        --talk=org.freedesktop.StatusNotifierWatcher \
        --broadcast=org.kde.StatusNotifierWatcher=/StatusNotifierWatcher,org.kde.StatusNotifierWatcher,* \
        --broadcast=org.freedesktop.StatusNotifierWatcher=/StatusNotifierWatcher,org.freedesktop.StatusNotifierWatcher,*
    '';

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
