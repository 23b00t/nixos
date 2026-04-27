{ pkgs, ... }:
let
  githubAgentScript = pkgs.writeShellScriptBin "github-agent" ''
    set -eu

    AGENT_DIR="$HOME/.ssh/agent"
    SOCKET_PATH="$AGENT_DIR/github.sock"
    KEY_PATH="$HOME/.ssh/id_ed25519"
    ENV_PATH="$AGENT_DIR/github-agent.env"

    mkdir -p "$AGENT_DIR"
    chmod 700 "$AGENT_DIR"

    if [ ! -f "$KEY_PATH" ]; then
      echo "GitHub SSH key not found at '$KEY_PATH'." >&2
      exit 1
    fi

    existing_pid=""
    if [ -f "$ENV_PATH" ]; then
      # shellcheck disable=SC1090
      . "$ENV_PATH"
      existing_pid="''${SSH_AGENT_PID:-}"
    fi

    if [ -S "$SOCKET_PATH" ] && [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
      export SSH_AUTH_SOCK="$SOCKET_PATH"
      export SSH_AGENT_PID="$existing_pid"
    else
      rm -f "$SOCKET_PATH"
      eval "$(${pkgs.openssh}/bin/ssh-agent -a "$SOCKET_PATH" -s)" >/dev/null
      printf 'SSH_AUTH_SOCK=%s\nSSH_AGENT_PID=%s\n' "$SSH_AUTH_SOCK" "$SSH_AGENT_PID" > "$ENV_PATH"
      chmod 600 "$ENV_PATH"
    fi

    if ! ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
      ${pkgs.openssh}/bin/ssh-add "$KEY_PATH"
    elif ! ${pkgs.openssh}/bin/ssh-add -L 2>/dev/null | ${pkgs.gnugrep}/bin/grep -F "$(cat "$KEY_PATH.pub")" >/dev/null; then
      ${pkgs.openssh}/bin/ssh-add "$KEY_PATH"
    fi

    echo "GitHub agent ready at $SOCKET_PATH"
  '';
in
{
  home.packages = [ githubAgentScript ];
}
