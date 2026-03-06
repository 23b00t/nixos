# filepath: home/vm-connect.nix
{ pkgs, lib, ... }:
let
  vmRegistry = import ../vms/registry.nix { inherit lib; };

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

  vmScript = pkgs.writeShellScriptBin "vm" ''
    USE_KITTEN=0

    # Check for -k flag
    if [ "$1" = "-k" ]; then
      USE_KITTEN=1
      shift
    fi

    NAME="$1"

    if [ -z "$NAME" ]; then
      echo "Usage: vm [-k] <vm-name-or-short>"
      echo "Available VMs:"
      cat <<EOF
${vmList}
EOF
      exit 1
    fi

    # Resolve VM by name or short name using generated case statement
    case "$NAME" in
${vmCases}
      *)
        echo "Error: Unknown VM '$NAME'"
        exit 1
        ;;
    esac

    USER="user"
    KEY="$HOME/.ssh/${FULL_NAME}-vm"

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

