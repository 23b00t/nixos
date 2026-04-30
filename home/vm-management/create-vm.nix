{ pkgs, ... }:
pkgs.writeShellScriptBin "create-vm" ''
  #!/usr/bin/env bash
  set -euo pipefail

  usage() {
    cat <<EOF
Usage: create-vm [options]

Options:
  --name <name>                         VM name (required in non-interactive mode)
  --short <shortname>                   VM short name
  --profile <default|minimal|coding>    Module profile
  --autostart <true|false>
  --nat <true|false>
  --allow-github-agent <true|false>
  --enable-host-dbus-forward <true|false>
  --persistent-store-overlay <true|false>
  --mem <MiB>
  --vcpus <count>
  --home-img-size <MiB>
  --ip <10.0.0.X>
  --host-ssh-key <public-key>
  --force                               Overwrite existing VM flake if present
  -h, --help                            Show this help

Notes:
  - If --ip is not provided, the next free IP after the current max (<253) is used.
  - If --host-ssh-key is not provided, ~/.ssh/<name>-vm(.pub) is created/read.
EOF
  }

  bool_normalize() {
    case "$1" in
      true|TRUE|yes|YES|y|Y|1|on|ON) echo "true" ;;
      false|FALSE|no|NO|n|N|0|off|OFF) echo "false" ;;
      *)
        echo "Invalid boolean value: $1" >&2
        exit 1
        ;;
    esac
  }

  prompt_input() {
    local question="$1"
    local default_value="$2"
    local value
    if [ -n "$default_value" ]; then
      read -r -p "$question [$default_value]: " value
      if [ -z "$value" ]; then
        value="$default_value"
      fi
    else
      read -r -p "$question: " value
    fi
    echo "$value"
  }

  prompt_bool() {
    local question="$1"
    local default_value="$2"
    local value
    while true; do
      read -r -p "$question [$default_value]: " value
      if [ -z "$value" ]; then
        value="$default_value"
      fi
      case "$(bool_normalize "$value")" in
        true) echo "true"; return ;;
        false) echo "false"; return ;;
      esac
    done
  }

  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$HOME/nixos-config"
  fi

  TOP_FLAKE="$REPO_ROOT/flake.nix"
  REGISTRY_FILE="$REPO_ROOT/vms/registry.nix"
  TEMPLATE_FILE="$REPO_ROOT/vms/templates/base.nix"

  [ -f "$TOP_FLAKE" ] || { echo "Missing file: $TOP_FLAKE" >&2; exit 1; }
  [ -f "$REGISTRY_FILE" ] || { echo "Missing file: $REGISTRY_FILE" >&2; exit 1; }
  [ -f "$TEMPLATE_FILE" ] || { echo "Missing file: $TEMPLATE_FILE" >&2; exit 1; }

  VM_NAME=""
  VM_SHORT=""
  PROFILE=""
  AUTOSTART=""
  NAT=""
  ALLOW_GITHUB_AGENT=""
  ENABLE_HOST_DBUS_FORWARD=""
  PERSISTENT_OVERLAY=""
  MEM=""
  VCPUS=""
  HOME_IMG_SIZE=""
  VM_IP=""
  HOST_SSH_KEY=""
  FORCE=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --name)
        VM_NAME="$2"
        shift 2
        ;;
      --short)
        VM_SHORT="$2"
        shift 2
        ;;
      --profile)
        PROFILE="$2"
        shift 2
        ;;
      --autostart)
        AUTOSTART="$(bool_normalize "$2")"
        shift 2
        ;;
      --nat)
        NAT="$(bool_normalize "$2")"
        shift 2
        ;;
      --allow-github-agent)
        ALLOW_GITHUB_AGENT="$(bool_normalize "$2")"
        shift 2
        ;;
      --enable-host-dbus-forward)
        ENABLE_HOST_DBUS_FORWARD="$(bool_normalize "$2")"
        shift 2
        ;;
      --persistent-store-overlay)
        PERSISTENT_OVERLAY="$(bool_normalize "$2")"
        shift 2
        ;;
      --mem)
        MEM="$2"
        shift 2
        ;;
      --vcpus)
        VCPUS="$2"
        shift 2
        ;;
      --home-img-size)
        HOME_IMG_SIZE="$2"
        shift 2
        ;;
      --ip)
        VM_IP="$2"
        shift 2
        ;;
      --host-ssh-key)
        HOST_SSH_KEY="$2"
        shift 2
        ;;
      --force)
        FORCE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [ -z "$PROFILE" ]; then
    echo "Choose profile:"
    echo "  1) default"
    echo "  2) minimal"
    echo "  3) coding"
    while true; do
      read -r -p "Profile [default]: " profile_input
      profile_input="''${profile_input:-default}"
      case "$profile_input" in
        1|default) PROFILE="default"; break ;;
        2|minimal) PROFILE="minimal"; break ;;
        3|coding) PROFILE="coding"; break ;;
        *) echo "Please choose: default, minimal, or coding." ;;
      esac
    done
  fi

  case "$PROFILE" in
    default|minimal|coding) ;;
    *)
      echo "Invalid --profile value: $PROFILE" >&2
      exit 1
      ;;
  esac

  if [ -z "$VM_NAME" ]; then
    VM_NAME="$(prompt_input "VM name" "")"
  fi
  if ! echo "$VM_NAME" | grep -Eq '^[a-z][a-z0-9-]*$'; then
    echo "Invalid VM name '$VM_NAME'. Use: lowercase letters, digits, '-' and start with letter." >&2
    exit 1
  fi

  if [ -z "$VM_SHORT" ]; then
    VM_SHORT="$(prompt_input "VM shortname" "$VM_NAME")"
  fi

  if [ -z "$AUTOSTART" ]; then
    AUTOSTART="$(prompt_bool "Autostart" "false")"
  fi
  if [ -z "$NAT" ]; then
    NAT="$(prompt_bool "NAT" "true")"
  fi
  if [ -z "$ALLOW_GITHUB_AGENT" ]; then
    ALLOW_GITHUB_AGENT="$(prompt_bool "allowGitHubAgent" "false")"
  fi
  if [ -z "$ENABLE_HOST_DBUS_FORWARD" ]; then
    ENABLE_HOST_DBUS_FORWARD="$(prompt_bool "enableHostDbusForward" "true")"
  fi
  if [ -z "$MEM" ]; then
    MEM="$(prompt_input "Memory (MiB)" "4096")"
  fi
  if [ -z "$VCPUS" ]; then
    VCPUS="$(prompt_input "vCPUs" "2")"
  fi
  if [ -z "$HOME_IMG_SIZE" ]; then
    HOME_IMG_SIZE="$(prompt_input "home.img size (MiB)" "20000")"
  fi
  if [ -z "$PERSISTENT_OVERLAY" ]; then
    PERSISTENT_OVERLAY="$(prompt_bool "With persistent store overlay" "false")"
  fi

  if ! echo "$MEM" | grep -Eq '^[0-9]+$'; then
    echo "--mem must be a positive integer" >&2
    exit 1
  fi
  if ! echo "$VCPUS" | grep -Eq '^[0-9]+$'; then
    echo "--vcpus must be a positive integer" >&2
    exit 1
  fi
  if ! echo "$HOME_IMG_SIZE" | grep -Eq '^[0-9]+$'; then
    echo "--home-img-size must be a positive integer" >&2
    exit 1
  fi

  if grep -qE "^[[:space:]]*name = \"$VM_NAME\";" "$REGISTRY_FILE"; then
    echo "VM name '$VM_NAME' already exists in registry." >&2
    exit 1
  fi
  if grep -qE "^[[:space:]]*short = \"$VM_SHORT\";" "$REGISTRY_FILE"; then
    echo "VM short '$VM_SHORT' already exists in registry." >&2
    exit 1
  fi

  if [ -z "$VM_IP" ]; then
    max_ip="$(${pkgs.gnugrep}/bin/grep -oE '10\.0\.0\.[0-9]+' "$REGISTRY_FILE" | ${pkgs.gawk}/bin/awk -F. '$4 < 253 { if ($4 > max) max = $4 } END { print max + 0 }')"
    VM_IP="10.0.0.$((max_ip + 1))"
  fi

  if ! echo "$VM_IP" | grep -Eq '^10\.0\.0\.([0-9]{1,3})$'; then
    echo "IP must be in form 10.0.0.X" >&2
    exit 1
  fi

  octet="$(echo "$VM_IP" | ${pkgs.gawk}/bin/awk -F. '{print $4}')"
  if [ "$octet" -ge 253 ]; then
    echo "IP octet must be < 253 (got $octet)." >&2
    exit 1
  fi

  if grep -q "ip = \"$VM_IP\";" "$REGISTRY_FILE"; then
    echo "IP '$VM_IP' already exists in registry." >&2
    exit 1
  fi

  NET_INDEX="$octet"
  MAC_SUFFIX="$(printf '%02x' "$NET_INDEX")"
  MAC_ADDR="00:00:00:00:00:$MAC_SUFFIX"

  VM_DIR="$REPO_ROOT/vms/$VM_NAME"
  VM_FLAKE="$VM_DIR/flake.nix"

  mkdir -p "$VM_DIR"

  if [ -f "$VM_FLAKE" ] && [ "$FORCE" -ne 1 ]; then
    echo "File exists: $VM_FLAKE (use --force to overwrite)" >&2
    exit 1
  fi

  if [ -z "$HOST_SSH_KEY" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    key_path="$HOME/.ssh/$VM_NAME-vm"
    if [ ! -f "$key_path" ]; then
      ssh-keygen -t ed25519 -f "$key_path" -N "" -C "$VM_NAME-vm" >/dev/null
      echo "Created SSH key: $key_path"
    fi
    if [ ! -f "$key_path.pub" ]; then
      echo "Missing public key: $key_path.pub" >&2
      exit 1
    fi
    HOST_SSH_KEY="$(cat "$key_path.pub")"
  fi

  MODULE_IMPORTS=$'          ../modules/net-config.nix\n          ../modules/common-config.nix'
  EXTRA_SERVICE_BLOCKS=""
  PERSISTENT_MODULE_IMPORT=""
  PERSISTENT_SERVICE_LINE=""

  case "$PROFILE" in
    default)
      MODULE_IMPORTS+=$'\n          ../modules/yazi-config.nix\n          ../modules/wprs.nix'
      ;;
    minimal)
      ;;
    coding)
      if [ "$ALLOW_GITHUB_AGENT" = "true" ]; then
        EXTRA_SERVICE_BLOCKS=$'\n              services.ide = {\n                enable = true;\n                githubAgent.enable = true;\n              };\n              services.zsh-env.enable = true;\n              services.zellij-env.enable = true;'
      else
        EXTRA_SERVICE_BLOCKS=$'\n              services.ide.enable = true;\n              services.zsh-env.enable = true;\n              services.zellij-env.enable = true;'
      fi
      MODULE_IMPORTS+=$'\n          ../modules/ide.nix\n          ../modules/zsh.nix\n          ../modules/zellij.nix'
      ;;
  esac

  if [ "$PERSISTENT_OVERLAY" = "true" ]; then
    PERSISTENT_MODULE_IMPORT=$'\n          ../modules/persistent-store-overlay.nix'
    PERSISTENT_SERVICE_LINE=$'\n              services.persistentStoreOverlay.enable = true;'
  fi

  tmp_vm_flake="$(mktemp)"

  ${pkgs.gawk}/bin/awk \
    -v vmName="$VM_NAME" \
    -v moduleImports="$MODULE_IMPORTS$PERSISTENT_MODULE_IMPORT" \
    -v netIndex="$NET_INDEX" \
    -v macAddr="$MAC_ADDR" \
    -v homeImgSize="$HOME_IMG_SIZE" \
    -v mem="$MEM" \
    -v vcpus="$VCPUS" \
    -v extraServiceBlocks="$EXTRA_SERVICE_BLOCKS" \
    -v persistentServiceLine="$PERSISTENT_SERVICE_LINE" \
    '{
      gsub(/__VM_NAME__/, vmName)
      gsub(/__MODULE_IMPORTS__/, moduleImports)
      gsub(/__NET_INDEX__/, netIndex)
      gsub(/__MAC_ADDR__/, macAddr)
      gsub(/__HOME_IMG_SIZE__/, homeImgSize)
      gsub(/__MEM__/, mem)
      gsub(/__VCPUS__/, vcpus)
      gsub(/__EXTRA_SERVICE_BLOCKS__/, extraServiceBlocks)
      gsub(/__PERSISTENT_SERVICE_LINE__/, persistentServiceLine)
      print
    }' "$TEMPLATE_FILE" > "$tmp_vm_flake"

  mv "$tmp_vm_flake" "$VM_FLAKE"
  echo "Created $VM_FLAKE"

  if grep -qE "^[[:space:]]*$VM_NAME\.url = \"path:\./vms/$VM_NAME\";" "$TOP_FLAKE"; then
    echo "Top-level flake input already exists for '$VM_NAME', skipping insert."
  else
    last_vm_url_line="$(grep -nE '^[[:space:]]*[a-zA-Z0-9-]+\.url = "path:\./vms/[a-zA-Z0-9-]+";' "$TOP_FLAKE" | tail -n1 | cut -d: -f1)"
    if [ -z "$last_vm_url_line" ]; then
      echo "Could not find VM input lines in $TOP_FLAKE" >&2
      exit 1
    fi

    sed -i "''${last_vm_url_line}a\    $VM_NAME.url = \"path:./vms/$VM_NAME\";" "$TOP_FLAKE"
    echo "Updated $TOP_FLAKE"
  fi

  vm_block_file="$(mktemp)"
  cat > "$vm_block_file" <<EOF
    {
      name = "$VM_NAME";
      short = "$VM_SHORT";
      ip = "$VM_IP";
      autostart = $AUTOSTART;
      nat = $NAT;
      hostSSHKey = "$HOST_SSH_KEY";
      allowGitHubAgent = $ALLOW_GITHUB_AGENT;
      enableHostDbusForward = $ENABLE_HOST_DBUS_FORWARD;
    }
EOF

  vms_end_line="$(${pkgs.gawk}/bin/awk '
    /^[[:space:]]*vms = \[/ { in_vms = 1; next }
    in_vms && /^[[:space:]]*\];/ { print NR; exit }
  ' "$REGISTRY_FILE")"

  if [ -z "$vms_end_line" ]; then
    echo "Could not find end of 'vms = [ ... ]' in $REGISTRY_FILE" >&2
    exit 1
  fi

  insert_after_line=$((vms_end_line - 1))
  sed -i "''${insert_after_line}r $vm_block_file" "$REGISTRY_FILE"
  rm -f "$vm_block_file"

  echo "Updated $REGISTRY_FILE"
  echo
  echo "VM '$VM_NAME' created successfully."
  echo "Summary:"
  echo "  profile:                 $PROFILE"
  echo "  ip:                      $VM_IP"
  echo "  net index:               $NET_INDEX"
  echo "  mac:                     $MAC_ADDR"
  echo "  autostart:               $AUTOSTART"
  echo "  nat:                     $NAT"
  echo "  allowGitHubAgent:        $ALLOW_GITHUB_AGENT"
  echo "  enableHostDbusForward:   $ENABLE_HOST_DBUS_FORWARD"
  echo "  mem:                     $MEM"
  echo "  vcpus:                   $VCPUS"
  echo "  home.img size:           $HOME_IMG_SIZE"
''
