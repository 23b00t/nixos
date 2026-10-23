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
  microvm.shares = [
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

  services = {
    ide.lazyvimRepo = "git@github.com:23b00t/lazyvim.git";

    zellij-env.tabsKdlFile = builtins.path {
      name = "tabs.kdl";
      path = ./nvim/tabs.kdl;
    };

    zsh-env = {
      ohMyPoshTheme = "1_shell.omp.json";
      extraAliases = {
        edit = "sudo -e";
      };
    };
  };
}
