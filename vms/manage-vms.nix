{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "microvm-batch-control" ''
  set -e

  if [ $# -ne 1 ]; then
    echo "Usage: microvm-batch-control <systemctl-action>"
    exit 1
  fi

  ACTION="$1"

  for vm in $(systemctl list-units --type=service --state=running 'microvm@*' | awk '/microvm@/ {print $1}'); do
    echo "Running: sudo systemctl $ACTION $vm"
    sudo -S systemctl "$ACTION" "$vm"
  done
''
