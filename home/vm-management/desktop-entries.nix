{ pkgs, lib, ... }:
let
  vmRegistry = import ../../vms/registry.nix;

  vmCases = builtins.concatStringsSep "\n" (map (vm:
    let
      patterns =
        if vm.short != null && vm.short != vm.name then
          "\"" + vm.name + "\"|\"" + vm.short + "\""
        else
          "\"" + vm.name + "\"";
    in
      "      " + patterns + ")\n" +
      "        IP=\"" + vm.ip + "\"\n" +
      "        FULL_NAME=\"" + vm.name + "\"\n" +
      "        ;;"
  ) vmRegistry.vms);

  vmList = builtins.concatStringsSep "\n" (map (vm:
    if vm.short != null && vm.short != vm.name then
      "  ${vm.name} (${vm.short})"
    else
      "  ${vm.name}"
  ) vmRegistry.vms);

  # Generisches Wrapper-Skript: vm-run [-c] <vm-name-or-short> <binary> [args...]
  vmRunner = pkgs.writeShellScriptBin "vm-run" ''
    #!/usr/bin/env bash

    CLI_MODE=0

    # -c: direkt ssh statt wprs
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

    VM_KEY="$1"
    BINARY="$2"
    shift 2

    if [ -z "$VM_KEY" ] || [ -z "$BINARY" ]; then
      echo "Usage: vm-run [-c] <vm-name-or-short> <binary> [args...]"
      echo "Available VMs:"
      cat <<EOF
${vmList}
EOF
      exit 1
    fi

    # Resolve VM by name or short name using generated case statement
    case "$VM_KEY" in
${vmCases}
      *)
        echo "Error: Unknown VM '$VM_KEY'"
        exit 1
        ;;
    esac

    USER="user"
    KEY="$HOME/.ssh/''${FULL_NAME}-vm"
    SERVICE="microvm@''${FULL_NAME}.service"

    # Prüfen, ob der Service läuft
    if ! systemctl is-active --quiet "$SERVICE"; then
      ${pkgs.libnotify}/bin/notify-send "Starting VM: ''${FULL_NAME}" "Please wait..."
      systemctl start "$SERVICE"
      MAX_RETRIES=30
      COUNT=0
      while ! ping -c 1 -W 1 "$IP" &> /dev/null; do
        sleep 1
        COUNT=$((COUNT+1))
        if [ $COUNT -ge $MAX_RETRIES ]; then
          ${pkgs.libnotify}/bin/notify-send "Error" "VM ''${FULL_NAME} failed to start network."
          exit 1
        fi
      done
      sleep 2 # short break to ensure VM is ready
    fi

    if [ "$CLI_MODE" -eq 1 ]; then
      exec ssh -i "$KEY" "$USER@$IP" -t -- "$BINARY" "$@"
    else
      wprs "$IP" run -- "$BINARY" "$@" &
      WPRS_PID=$!
      wait $WPRS_PID
      # SSH-Session aufräumen
      pkill -P $WPRS_PID ssh || true
    fi
  '';

  # Helper für Desktop-Entries: nutzt VM-Key (name oder short), nicht IP-Suffix
  mkVmEntry =
    {
      name,
      vm,               # name oder short aus registry.nix
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
        exec =
          if args == "" then
            "${lib.getExe vmRunner} ${vm} ${binary} %U"
          else
            "${lib.getExe vmRunner} ${vm} ${binary} ${args} %U";
        terminal = false;
        type = "Application";
      };
    };
in
{
  # vm-run für Debug / CLI verfügbar machen
  home.packages = [ vmRunner ];

  xdg.desktopEntries = lib.mkMerge [
    # --- Chat VM ---
    (mkVmEntry {
      name = "zoom";
      genericName = "Zoom Video Chat";
      vm = "chat"; # oder short name aus registry.nix
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
      vm = "chat";
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
      vm = "chat";
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
      vm = "chat";
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
      vm = "chat";
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
      vm = "chat";
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
      name = "element-desktop";
      genericName = "Element Matrix Client";
      vm = "chat";
      binary = "element-desktop";
      icon = "element-desktop";
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
      vm = "chat";
      binary = "google-chrome-stable";
      args = "--profile-directory=Default --app-id=ejhkdoiecgkmdpomoahkdihbcldkgjci";
      icon = "element";
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
    })

    # --- Office VM ---
    (mkVmEntry {
      name = "gimp";
      genericName = "GNU Image Manipulation Program";
      vm = "office";
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
      vm = "office";
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
      vm = "office";
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
      vm = "office";
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
      vm = "office";
      binary = "pdfarranger";
      icon = "pdfarranger";
      categories = [ "Office" ];
      mimeType = [ "application/pdf" ];
    })

    # --- Net VM ---
    (mkVmEntry {
      name = "Firefox Web Browser";
      genericName = "Web Browser";
      vm = "net";
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
      vm = "net";
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

    # --- Net Private VM ---
    (mkVmEntry {
      name = "Firefox Private Browser";
      genericName = "Web Browser";
      vm = "net-private";
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

    # ---- Vault VM ---
    (mkVmEntry {
      name = "KeePassXC";
      genericName = "Password Manager";
      vm = "vault";
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

    # ---- Coding VM ---
    (mkVmEntry {
      name = "postman";
      genericName = "API Client";
      vm = "nvim";
      binary = "postman";
      icon = "postman";
      categories = [
        "Development"
        "Utility"
      ];
    })

    (mkVmEntry {
      name = "dbeaver";
      genericName = "Database Manager";
      vm = "nvim";
      binary = "dbeaver";
      icon = "dbeaver";
      categories = [
        "Development"
        "Database"
      ];
    })

    (mkVmEntry {
      name = "firefox coding vm";
      genericName = "Web Browser";
      vm = "nvim";
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
