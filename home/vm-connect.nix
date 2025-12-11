# filepath: home/vm-connect.nix
{ pkgs, ... }:
let
  vmScript = pkgs.writeShellScriptBin "vm" ''
    USE_KITTEN=0
    
    # Check for -k flag
    if [ "$1" == "-k" ]; then
      USE_KITTEN=1
      shift
    fi

    NAME="$1"

    if [ -z "$NAME" ]; then
      echo "Usage: vm [-k] <vm-name>"
      echo "Available VMs: nvim, chat, office, irc"
      exit 1
    fi

    # IP Mapping
    case "$NAME" in
      "nvim"|"n")   IP="10.0.0.1" ;;
      "chat"|"c")   IP="10.0.0.2" ;;
      "office"|"o") IP="10.0.0.3" ;;
      "irc"|"i")    IP="10.0.0.11" ;;
      *)
        echo "Error: Unknown VM '$NAME'"
        exit 1
        ;;
    esac

    USER="user"
    KEY="$HOME/.ssh/$NAME-vm"

    if [ "$USE_KITTEN" -eq 1 ]; then
      exec kitten ssh -i "$KEY" "$USER@$IP" -t
    else
      exec ssh -i "$KEY" "$USER@$IP" -t
    fi
  '';
in
{
  home.packages = [ vmScript ];
}
