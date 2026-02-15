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
      "nvim"|"n")
        IP="10.0.0.1"
        FULL_NAME="nvim"
        ;;
      "chat"|"c")
        IP="10.0.0.2"
        FULL_NAME="chat"
        ;;
      "test"|"t")
        IP="10.0.0.3"
        FULL_NAME="test"
        ;;
      "music"|"m")
        IP="10.0.0.4"
        FULL_NAME="music"
        ;;
      "net")
        IP="10.0.0.5"
        FULL_NAME="net"
        ;;
      "net-private"|"np")
        IP="10.0.0.6"
        FULL_NAME="net-private"
        ;;
      "wine"|"w")
        IP="10.0.0.7"
        FULL_NAME="wine"
        ;;
      "kali"|"k")
        IP="10.0.0.8"
        FULL_NAME="kali"
        ;;
      "office"|"o")
        IP="10.0.0.9"
        FULL_NAME="office"
        ;;
      "vault"|"v")
        IP="10.0.0.10"
        FULL_NAME="vault"
        ;;
      "irc"|"i")
        IP="10.0.0.11"
        FULL_NAME="irc"
        ;;
      "steam"|"s")
        IP="10.0.0.12"
        FULL_NAME="steam"
        ;;
      "godot"|"g")
        IP="10.0.0.13"
        FULL_NAME="godot"
        ;;
      "mirage"|"mi")
        IP="10.0.0.14"
        FULL_NAME="mirage"
        ;;
      *)
        echo "Error: Unknown VM '$NAME'"
        exit 1
        ;;
    esac

    USER="user"
    KEY="$HOME/.ssh/$FULL_NAME-vm"

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
