# filepath: home/desktop-entries.nix
{ pkgs, lib, ... }:
let
  # 1. Das generische Wrapper-Skript
  # Es nimmt IP-Suffix, VM-Name und Binary entgegen.
  vmRunner = pkgs.writeShellScriptBin "vm-run" ''
    #!/usr/bin/env bash

    CLI_MODE=0

    # Argumente parsen
    while getopts "c" opt; do
      case $opt in
        c)
          CLI_MODE=1
          ;;
        *)
          ;;
      esac
    done
    shift $((OPTIND -1))

    SUFFIX="$1"
    VM_NAME="$2"
    BINARY="$3"
    shift 3

    IP="10.0.0.$SUFFIX"
    SERVICE="microvm@$VM_NAME.service"

    # Prüfen, ob der Service läuft
    if ! systemctl is-active --quiet "$SERVICE"; then
      ${pkgs.libnotify}/bin/notify-send "Starting VM: $VM_NAME" "Please wait..."
      systemctl start "$SERVICE"
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
      sleep 2 # short break to ensure VM is ready
    fi

    if [ "$CLI_MODE" -eq 1 ]; then
      exec ssh -i ~/.ssh/"$VM_NAME"-vm user@"$IP" -t -- "$BINARY" "$@"
    else
      wprs "$IP" run -- "$BINARY" "$@" &
      WPRS_PID=$!
      wait $WPRS_PID
      # SSH-Session aufräumen
      pkill -P $WPRS_PID ssh
    fi
  '';

  # 2. Die Helper-Funktion
  # Sie transformiert unsere Custom-Daten in valides XDG-Format
  mkVmEntry =
    {
      name,
      vmName,
      ipSuffix,
      binary,
      genericName ? name,
      categories ? [ ],
      mimeType ? [ ],
      icon ? null,
      args ? "",
    }:
    {
      "${name}" = {
        inherit
          name
          genericName
          categories
          mimeType
          icon
          ;
        exec = "${lib.getExe vmRunner} ${toString ipSuffix} ${vmName} ${binary} ${args} %U";
        terminal = false;
        type = "Application";
      };
    };
in
{
  # Das Skript verfügbar machen (optional, gut zum Debuggen im Terminal: `vm-run 2 chat zoom-us`)
  home.packages = [ vmRunner ];

  xdg.desktopEntries = lib.mkMerge [
    # --- Chat VM (10.0.0.2) ---

    # FIXME: Doesn't work
    (mkVmEntry {
      name = "zoom"; # Key im desktopEntries Set (wird zu zoom.desktop)
      genericName = "Zoom Video Chat";
      vmName = "chat";
      ipSuffix = 2;
      # binary = "zoom-us";
      # args = "--disable-gpu";
      binary = "flatpak";
      args = "run us.zoom.Zoom";
      icon = "Zoom";
      categories = [
        "Network"
        "VideoConference"
      ];
      mimeType = [
        "x-scheme-handler/zoommtg"
        "x-scheme-handler/zoomus"
        "application/x-zoom"
      ];
    })

    (mkVmEntry {
      name = "vesktop";
      genericName = "Discord Client";
      vmName = "chat";
      ipSuffix = 2;
      binary = "vesktop";
      icon = "discord";
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
    })

    (mkVmEntry {
      name = "telegram-desktop";
      genericName = "Telegram Desktop";
      vmName = "chat";
      ipSuffix = 2;
      binary = "Telegram";
      icon = "telegram";
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      mimeType = [ "x-scheme-handler/tg" ];
    })

    (mkVmEntry {
      name = "slack";
      genericName = "Slack";
      vmName = "chat";
      ipSuffix = 2;
      binary = "slack";
      icon = "slack";
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      mimeType = [ "x-scheme-handler/slack" ];
    })

    (mkVmEntry {
      name = "google-chrome";
      genericName = "Web Browser";
      vmName = "chat";
      ipSuffix = 2;
      binary = "google-chrome-stable";
      icon = "google-chrome";
      categories = [
        "Network"
        "WebBrowser"
      ];
    })

    (mkVmEntry {
      name = "teams";
      genericName = "Microsoft Teams (PWA)";
      vmName = "chat";
      ipSuffix = 2;
      binary = "google-chrome-stable";
      args = "--profile-directory=Default --app-id=cifhbcnohmdccbgoicgdjpfamggdegmo";
      icon = "teams";
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      mimeType = [ "x-scheme-handler/web+msteams" ];
    })

    (mkVmEntry {
      name = "element";
      genericName = "Element";
      vmName = "chat";
      ipSuffix = 2;
      binary = "google-chrome-stable";
      args = "--profile-directory=Default --app-id=ejhkdoiecgkmdpomoahkdihbcldkgjci";
      icon = "element";
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      mimeType = [ "x-scheme-handler/web+msteams" ];
    })
    # --- Office VM (10.0.0.9) ---

    # (mkVmEntry {
    #   name = "onlyoffice-desktopeditors";
    #   genericName = "Office Suite";
    #   vmName = "office";
    #   ipSuffix = 3;
    #   binary = "bash";
    #   args = "-c remmina --disable-toolbar -c /home/deinuser/.local/share/remmina/group_rdp_onlyoffice_10-0-0-3.remmina \> /dev/null 2\>\&1 \&";
    #   icon = "onlyoffice-desktopeditors";
    #   categories = [
    #     "Office"
    #     "WordProcessor"
    #     "Spreadsheet"
    #     "Presentation"
    #   ];
    #   mimeType = [
    #     "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    #     "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    #     "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    #   ];
    # })

    (mkVmEntry {
      name = "gimp";
      genericName = "GNU Image Manipulation Program";
      vmName = "office";
      ipSuffix = 9;
      binary = "gimp";
      icon = "gimp";
      categories = [
        "Graphics"
        "2DGraphics"
        "RasterGraphics"
      ];
      mimeType = [
        "image/jpeg"
        "image/png"
        "image/tiff"
        "image/webp"
      ];
    })

    (mkVmEntry {
      name = "inkscape";
      genericName = "Vector Graphics Editor";
      vmName = "office";
      ipSuffix = 9;
      binary = "inkscape";
      icon = "inkscape";
      categories = [
        "Graphics"
        "VectorGraphics"
      ];
      mimeType = [
        "image/svg+xml"
        "application/pdf"
      ];
    })

    (mkVmEntry {
      name = "vlc";
      genericName = "Media Player";
      vmName = "office";
      ipSuffix = 9;
      binary = "vlc";
      icon = "vlc";
      categories = [
        "AudioVideo"
        "Player"
        "Recorder"
      ];
    })

    (mkVmEntry {
      name = "pinta";
      genericName = "Image Editor";
      vmName = "office";
      ipSuffix = 9;
      binary = "pinta";
      icon = "pinta";
      categories = [
        "Graphics"
        "2DGraphics"
      ];
    })

    (mkVmEntry {
      name = "pdfarranger";
      genericName = "PDF Arranger";
      vmName = "office";
      ipSuffix = 9;
      binary = "pdfarranger";
      icon = "pdfarranger";
      categories = [ "Office" ];
      mimeType = [ "application/pdf" ];
    })

    # --- Net VM
    (mkVmEntry {
      name = "Firefox Web Browser";
      genericName = "Web Browser";
      vmName = "net";
      ipSuffix = 5;
      binary = "firefox";
      icon = "firefox";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "application/xhtml+xml"
        "application/xml"
        "application/pdf"
        "application/x-xpinstall"
      ];
    })
    (mkVmEntry {
      name = "Zen Browser";
      genericName = "Web Browser";
      vmName = "net";
      ipSuffix = 5;
      binary = "zen";
      icon = "web-browser";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "application/xhtml+xml"
        "application/xml"
        "application/pdf"
        "application/x-xpinstall"
      ];
    })

    # --- Net Private VM
    (mkVmEntry {
      name = "Firefox Private Browser";
      genericName = "Web Browser";
      vmName = "net-private";
      ipSuffix = 6;
      binary = "firefox";
      icon = "firefox";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "application/xhtml+xml"
        "application/xml"
        "application/pdf"
        "application/x-xpinstall"
      ];
    })

    # ---- Vault VM
    (mkVmEntry {
      name = "KeePassXC";
      genericName = "Password Manager";
      vmName = "vault";
      ipSuffix = 10;
      binary = "keepassxc";
      icon = "keepassxc";
      categories = [
        "Utility"
      ];
      mimeType = [
        "application/x-keepass2"
        "application/x-keepass"
      ];
    })

    # ---- Coding VM
    (mkVmEntry {
      name = "postman";
      genericName = "API Client";
      vmName = "nvim";
      ipSuffix = 1;
      binary = "postman";
      icon = "postman";
      categories = [
        "Development"
        "Utility"
      ];
      mimeType = [ ];
    })

    (mkVmEntry {
      name = "dbeaver";
      genericName = "Database Manager";
      vmName = "nvim";
      ipSuffix = 1;
      binary = "dbeaver";
      icon = "dbeaver";
      categories = [
        "Development"
        "Database"
      ];
      mimeType = [ ];
    })

    (mkVmEntry {
      name = "firefox coding vm";
      genericName = "Web Browser";
      vmName = "nvim";
      ipSuffix = 1;
      binary = "firefox";
      icon = "firefox";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "application/xhtml+xml"
        "application/xml"
        "application/pdf"
        "application/x-xpinstall"
      ];
    })
  ];
}
