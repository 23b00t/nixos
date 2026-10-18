{ pkgs, ... }:
let
  # Full system update, step 1 (step 2: `update-all` in dom0): updates the
  # flake inputs of the repo in the current directory, commits flake.lock
  # (signed via commit.gpgsign) as "update" and pushes, because the builder
  # only builds signed commits from GitHub. /nix/store is read-only here and
  # there is no daemon: the input sources (~600 MB) go to a temporary store
  # on the home disk that is removed again after the run.
  flakeBump = pkgs.writeShellScriptBin "flake-bump" ''
    set -euo pipefail
    mkdir -p "$HOME/.cache"
    store="$(mktemp -d "$HOME/.cache/flake-bump.XXXXXX")"
    # Store paths are read-only
    trap 'chmod -R u+w "$store" 2>/dev/null; rm -rf "$store"' EXIT
    root="$(git rev-parse --show-toplevel)"
    cd "$root"
    if [ ! -f flake.lock ]; then
      echo "flake-bump: no flake.lock in $root" >&2
      exit 1
    fi
    if ! git diff --quiet || ! git diff --cached --quiet; then
      echo "flake-bump: uncommitted changes in $root, commit or stash them first" >&2
      exit 1
    fi
    # Arguments: only these inputs (e.g. `flake-bump nixpkgs`)
    nix --extra-experimental-features "nix-command flakes" \
      --store "$store" flake update "$@"
    if git diff --quiet flake.lock; then
      echo "flake-bump: inputs already up to date"
      exit 0
    fi
    read -r -p "flake-bump: commit flake.lock as \"update\" and push? [y/N] " answer
    case "$answer" in
      y | Y) ;;
      *)
        echo "flake-bump: left uncommitted (git checkout flake.lock to drop it)"
        exit 0
        ;;
    esac
    git commit -m update flake.lock
    git push
    echo "flake-bump: pushed, now run update-all in dom0"
  '';
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/yazi-config.nix
    ../modules/ide.nix
    ../modules/zsh.nix
    ../modules/zellij.nix
    ../modules/common-config.nix
    # Terminal (foot) over wprs as a niri tab in dom0
    ../modules/wprs.nix
  ];

  networking.hostName = "nvim-vm";

  microvm = {
    
    hypervisor = "xen";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = 10000;
      }
    ];
    shares = [
      {
        proto = "virtiofs";
        tag = "host-home";
        source = "/home/nx";
        mountPoint = "/mnt/host";
      }
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    # Boots with 2048 MB, the RAM balancer grows it up to 4096 MB
    mem = 4096;
    balloon = true;
    initialBalloonMem = 2048;
    vcpu = 2; # 1 vCPU: input lagged a little (xmg, 2026-10-17)
  };

  environment.systemPackages = with pkgs; [
    lua-language-server
    lua51Packages.lua
    lua51Packages.luarocks
    nixfmt
    nil
    nixdoc
    deadnix
    flakeBump
  ];

  services.net-config = {
    enable = true;
    index = 1;
    mac = "00:00:00:00:00:01";
  };

  services.common-config = {
    enable = true;
  };

  services.ide = {
    enable = true;
    githubAgent.enable = true;
    lazyvimRepo = "git@github.com:23b00t/lazyvim.git";
  };

  services.zellij-env = {
    enable = true;
    tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./tabs.kdl;
    };
  };

  services.zsh-env = {
    enable = true;
    ohMyPoshTheme = "1_shell.omp.json";

    extraAliases = {
      edit = "sudo -e";
    };
  };

  system.stateVersion = "26.05";
}
