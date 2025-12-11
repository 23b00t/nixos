# filepath: home/desktop-entries.nix
{ pkgs, lib, ... }:
let
  # 1. Das generische Wrapper-Skript
  # Es nimmt IP-Suffix, VM-Name und Binary entgegen.
  vmRunner = pkgs.writeShellScriptBin "vm-run" ''
    SUFFIX="$1"
    VM_NAME="$2"
    BINARY="$3"
    shift 3
    
    IP="10.0.0.$SUFFIX"
    SERVICE="microvm@$VM_NAME.service"

    # Prüfen, ob der Service läuft
    if ! systemctl is-active --quiet "$SERVICE"; then
      # Optional: Benachrichtigung senden
      ${pkgs.libnotify}/bin/notify-send "Starting VM: $VM_NAME" "Please wait..."
      
      # VM starten
      systemctl start "$SERVICE"
      
      # Warten bis Netzwerk da ist (Ping Loop)
      MAX_RETRIES=30
      COUNT=0
      while ! ping -c 1 -W 1 "$IP" &> /dev/null; do
        sleep 1
        COUNT=$((COUNT+1))
        if [ $COUNT -ge $MAX_RETRIES ]; then
          ${pkgs.libnotify}/bin/notify-send "Error" "VM $VM_NAME failed to start network."
          exit 1
        fi
      done
    fi

    # Anwendung via wprs starten
    # "$@" gibt eventuelle Argumente (wie URLs bei Zoom-Links) weiter
    exec wprs "$IP" run "$BINARY" "$@"
  '';

  # 2. Die Helper-Funktion
  # Sie transformiert unsere Custom-Daten in valides XDG-Format
  mkVmEntry = { 
    name, 
    vmName, 
    ipSuffix, 
    binary, 
    genericName ? name, 
    categories ? [], 
    mimeType ? [] 
  }: {
    "${name}" = {
      inherit name genericName categories mimeType;
      # Hier bauen wir den exec string zusammen
      exec = "${lib.getExe vmRunner} ${toString ipSuffix} ${vmName} ${binary} %U";
      terminal = false;
      type = "Application";
    };
  };

in
{
  # Das Skript verfügbar machen (optional, gut zum Debuggen im Terminal: `vm-run 2 chat zoom-us`)
  home.packages = [ vmRunner ];

  xdg.desktopEntries = lib.mkMerge [
    # Hier definieren wir Zoom
    (mkVmEntry {
      name = "zoom"; # Key im desktopEntries Set (wird zu zoom.desktop)
      genericName = "Zoom Video Chat";
      vmName = "chat";
      ipSuffix = 2;
      binary = "zoom-us";
      categories = [ "Network" "VideoConference" ];
      mimeType = [ "x-scheme-handler/zoommtg" "x-scheme-handler/zoomus" "application/x-zoom" ];
    })

    # Beispiel für weitere App:
    # (mkVmEntry {
    #   name = "signal";
    #   vmName = "chat";
    #   ipSuffix = 2;
    #   binary = "signal-desktop";
    # })
  ];
}
