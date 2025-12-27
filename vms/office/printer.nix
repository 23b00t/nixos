{ pkgs, ... }:
{
  hostPrinterTunnelScript = pkgs.writeShellScriptBin "host-printer-tunnel" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    HOST_IP="192.168.178.20"
    HOST_USER="nx"
    TUNNEL_PORT=1631
    SSH_KEY="/root/.ssh/host"
    SSH="${pkgs.openssh}/bin/ssh"
    LSOF="${pkgs.lsof}/bin/lsof"

    if ! $LSOF -i TCP:"$TUNNEL_PORT" >/dev/null 2>&1; then
      echo "Starting SSH tunnel to $HOST_IP"
      $SSH -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -f -N -L "$TUNNEL_PORT":127.0.0.1:631 "$HOST_USER@$HOST_IP"
    fi

    # Service bleibt aktiv
    while true; do sleep 3600; done
  '';

  hostPrintersAddScript = pkgs.writeShellScriptBin "host-printers-add" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    HOST_IP="192.168.178.20"
    HOST_USER="nx"
    TUNNEL_PORT=1631
    SSH_KEY="/root/.ssh/host"

    LPSTAT="${pkgs.cups}/bin/lpstat"
    LPADMIN="${pkgs.cups}/bin/lpadmin"
    SSH="${pkgs.openssh}/bin/ssh"
    AWK="${pkgs.gawk}/bin/awk"
    GREP="${pkgs.gnugrep}/bin/grep"

    # Warte bis Tunnel offen ist
    while ! ${pkgs.lsof}/bin/lsof -i TCP:"''${TUNNEL_PORT}" >/dev/null 2>&1; do
      echo "Waiting for tunnel on port ''${TUNNEL_PORT}..."
      sleep 1
    done

    # Druckerliste vom Host holen
    PRINTERS=$($SSH -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$HOST_USER@$HOST_IP" \
      "''${LPSTAT} -p | ''${AWK} '{print \$2}'")

    for PRINTER in $PRINTERS; do
      LP_NAME="HostPrinter_''${PRINTER}"
      if ! $LPSTAT -p | $GREP -q "^printer $LP_NAME "; then
        echo "Adding printer $LP_NAME..."
        $LPADMIN -p "$LP_NAME" -E -v "ipp://localhost:''${TUNNEL_PORT}/printers/''${PRINTER}" -m everywhere
      fi
    done
  '';
}
