# Builder VM (v2.4): evaluates and builds the host systems (incl. all MicroVMs
# and store group images) from the GitHub repo and signs the closures with its
# own key. dom0 pulls the result with `dom0-update` (modules/dom0-update.nix);
# the builder never pushes into dom0.
{ pkgs, config, ... }:
let
  stateDir = "/var/lib/builder";
  repoUrl = "https://github.com/23b00t/nixos";

  # builder-build <machine> [branch]: fetch, build, sign; prints the toplevel
  builderBuild = pkgs.writeShellScriptBin "builder-build" ''
    set -euo pipefail
    machine="''${1:?usage: builder-build <machine> [branch]}"
    branch="''${2:-$machine}"
    repo="${stateDir}/repo"
    key="${stateDir}/signing-key"

    [ -r "$key" ] || { echo "builder-build: signing key $key missing" >&2; exit 1; }

    if [ ! -d "$repo/.git" ]; then
      ${pkgs.git}/bin/git clone --quiet ${repoUrl} "$repo" >&2
    fi
    ${pkgs.git}/bin/git -C "$repo" fetch --quiet origin "$branch" >&2
    ${pkgs.git}/bin/git -C "$repo" checkout --quiet --detach FETCH_HEAD >&2
    echo "builder-build: $machine from $branch @ $(${pkgs.git}/bin/git -C "$repo" rev-parse --short HEAD)" >&2

    # The out-link is the GC root of the last build per machine
    out="$(${config.nix.package}/bin/nix build --print-out-paths \
      --out-link "${stateDir}/systems/$machine" \
      "$repo#nixosConfigurations.$machine.config.system.build.toplevel")"

    # Re-sign the whole closure: substituted paths only carry the cache's
    # signature, dom0 trusts nothing but this key
    ${config.nix.package}/bin/nix store sign --recursive --key-file "$key" "$out"

    echo "$out"
  '';
in
{
  imports = [
    ../modules/net-config.nix
    ../modules/common-config.nix
    ../modules/persistent-store-overlay.nix
  ];

  networking.hostName = "builder-vm";

  services = {
    net-config = {
      enable = true;
      index = 25;
      mac = "00:00:00:00:00:19";
      # internet via the sys-net uplink (registry `nat = true`)
    };

    common-config = {
      enable = true;
      withDefaultPkgs = false;
      vmCopy.enable = false;
    };

    persistentStoreOverlay = {
      enable = true;
      overlaySize = 100000;
    };
  };

  microvm = {
    # The own closure (lower store disk) must be valid in the Nix DB. Otherwise
    # building a system that contains it (dom0's, which includes the builder)
    # makes Nix delete those paths as invalid; the overlay keeps that as
    # whiteouts and hides them on the next boot (lost sshd-keygen, 2026-10-06)
    registerClosure = true;
    hypervisor = "xen";
    volumes = [
      {
        # Repo checkout, out-links, signing key and the build directories
        image = "builder.img";
        mountPoint = stateDir;
        size = 40000;
      }
      {
        # Persistent journal (e.g. to see OOM kills after a restart)
        image = "log.img";
        mountPoint = "/var/log";
        size = 2048;
      }
    ];
    # Boots with 4096 MB, the RAM balancer grows it up to 16384 MB
    # (evaluating the hp configuration peaks at ~6.6 GB)
    mem = 16384;
    balloon = true;
    initialBalloonMem = 12288;
    vcpu = 8;
  };

  systemd = {
    tmpfiles.rules = [
      "d ${stateDir} 0755 user users -"
      "d ${stateDir}/systems 0755 user users -"
      "d ${stateDir}/build 0755 root root -"
      # Out-links survive reboots, /nix/var does not: re-register them as GC
      # roots so the persistent store overlay keeps the last builds in its DB
      "L+ /nix/var/nix/gcroots/builder-hp - - - - ${stateDir}/systems/hp"
      "L+ /nix/var/nix/gcroots/builder-xmg - - - - ${stateDir}/systems/xmg"
    ];

    services = {
      # Signing key, generated in the VM on first boot; only the public part
      # leaves it (vms/builder/signing-key.pub, trusted by dom0)
      builder-signing-key = {
        description = "Generate the builder's Nix signing key";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        unitConfig.RequiresMountsFor = [ stateDir ];
        serviceConfig = {
          Type = "oneshot";
          User = "user";
          UMask = "0077";
        };
        path = [ config.nix.package ];
        script = ''
          if [ ! -e ${stateDir}/signing-key ]; then
            nix key generate-secret --key-name builder-vm-1 > ${stateDir}/signing-key
            nix key convert-secret-to-public < ${stateDir}/signing-key > ${stateDir}/signing-key.pub
            chmod 644 ${stateDir}/signing-key.pub
          fi
        '';
      };
    };
  };

  # nix.package (Lix, like dom0) comes from common-config
  nix.settings = {
    # RAM, not CPU, is the limit: the evaluator keeps its heap for the whole
    # build, and parallel mkfs.erofs runs (store images) ran out of memory
    # with "auto" (8). Each job still uses all cores.
    max-jobs = 2;
    # Build directories on the volume instead of the RAM-backed root
    # (default /nix/var/nix/b is on the 2 GB tmpfs). Lix uses build-dir, not
    # the daemon's TMPDIR (the daemon is socket-activated per connection).
    build-dir = "${stateDir}/build";
    # The store overlay holds the last hp closure; after each build the
    # previous one is garbage. GC during builds when space runs low.
    min-free = 5 * 1024 * 1024 * 1024;
    max-free = 15 * 1024 * 1024 * 1024;
  };
  systemd.sockets.nix-daemon.unitConfig.RequiresMountsFor = [ stateDir ];

  # The balancer can only grow the VM as far as free Xen RAM allows; zram
  # absorbs eval peaks beyond that instead of the OOM killer. The size is
  # taken from the boot RAM (4096 MB), so 200 % = ~8 GB uncompressed.
  zramSwap = {
    enable = true;
    memoryPercent = 200;
  };

  environment.systemPackages = [
    builderBuild
    pkgs.git
  ];

  system.stateVersion = "26.05";
}
