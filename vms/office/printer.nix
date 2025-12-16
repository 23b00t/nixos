{ pkgs, ... }:
{
  hostPrinterTunnelScript = pkgs.writeShellScriptBin "host-printer-tunnel" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    HOST_IP="192.168.178.200"
    HOST_USER="nx"
    TUNNEL_PORT=1631
    PRINTER_NAME="HP_LaserJet_M110w_42FA89"
    LP_NAME="HostPrinter"

    # Explizite Pfade zu den Programmen verwenden, um maximale Robustheit zu gewährleisten.
    LSOF="${pkgs.lsof}/bin/lsof"
    SSH="${pkgs.openssh}/bin/ssh"
    LPSTAT="${pkgs.cups}/bin/lpstat"
    LPADMIN="${pkgs.cups}/bin/lpadmin"
    GREP="${pkgs.gnugrep}/bin/grep"

    # Warten, bis der Host erreichbar ist, bevor der Tunnel versucht wird.
    # while ! ping -c 1 -W 1 ''${HOST_IP} &>/dev/null; do
    #     echo "Waiting for host ''${HOST_IP}..."
    #     sleep 2
    # done

    # In VM:
    # ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    # ssh-copy-id -i ~/.ssh/id_ed25519.pub nx@192.168.178.200
    # sudo cp /home/user/.ssh/host /root/.ssh/host
    # sudo chown root:root /root/.ssh/host
    # sudo chmod 600 /root/.ssh/host
    # Start SSH tunnel if not already running
    SSH_KEY="/root/.ssh/host"

    if ! $LSOF -i TCP:"$TUNNEL_PORT" >/dev/null 2>&1; then
        echo "Starting SSH tunnel to $HOST_IP"
        $SSH -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -f -N -L "$TUNNEL_PORT":127.0.0.1:631 "$HOST_USER@$HOST_IP"
    fi

    # Endlosschleife, damit der Service "simple" aktiv bleibt und nicht sofort beendet wird.
    # Dies ist wichtig, damit der forked-SSH-Prozess nicht verwaist und beendet wird.
    echo "Tunnel setup complete. Service is active."
    while true; do sleep 3600; done
  '';
}
