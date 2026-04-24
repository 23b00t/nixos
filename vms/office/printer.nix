# NOTE: The sys-net privat key SSH key must be present as /root/.ssh/print-gateway.
{ pkgs, ... }:
{
  printGatewayTunnelScript = pkgs.writeShellScriptBin "print-gateway-tunnel" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    PRINT_SERVER_IP="10.0.0.253"
    PRINT_SERVER_USER="user"
    TUNNEL_PORT=1631
    SSH_KEY="/root/.ssh/print-gateway"
    SSH="${pkgs.openssh}/bin/ssh"
    LSOF="${pkgs.lsof}/bin/lsof"

    if ! $LSOF -i TCP:"$TUNNEL_PORT" >/dev/null 2>&1; then
      echo "Starting SSH tunnel to $PRINT_SERVER_IP"
      $SSH -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -f -N -L "$TUNNEL_PORT":127.0.0.1:631 "$PRINT_SERVER_USER@$PRINT_SERVER_IP"
    fi

    while true; do sleep 3600; done
  '';

  printGatewayPrintersAddScript = pkgs.writeShellScriptBin "print-gateway-printers-add" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    PRINT_SERVER_IP="10.0.0.253"
    PRINT_SERVER_USER="user"
    TUNNEL_PORT=1631
    SSH_KEY="/root/.ssh/print-gateway"

    LPSTAT="${pkgs.cups}/bin/lpstat"
    LPADMIN="${pkgs.cups}/bin/lpadmin"
    SSH="${pkgs.openssh}/bin/ssh"
    AWK="${pkgs.gawk}/bin/awk"
    GREP="${pkgs.gnugrep}/bin/grep"

    while ! ${pkgs.lsof}/bin/lsof -i TCP:"''${TUNNEL_PORT}" >/dev/null 2>&1; do
      echo "Waiting for tunnel on port ''${TUNNEL_PORT}..."
      sleep 1
    done

    PRINTERS=$($SSH -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$PRINT_SERVER_USER@$PRINT_SERVER_IP" \
      "''${LPSTAT} -p | ''${AWK} '{print \$2}'")

    for PRINTER in $PRINTERS; do
      LP_NAME="PrintGateway_''${PRINTER}"
      if ! $LPSTAT -p | $GREP -q "^printer $LP_NAME "; then
        echo "Adding printer $LP_NAME..."
        $LPADMIN -p "$LP_NAME" -E -v "ipp://localhost:''${TUNNEL_PORT}/printers/''${PRINTER}" -m everywhere
      fi
    done
  '';
}
