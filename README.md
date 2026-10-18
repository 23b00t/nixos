# NixOS: Xen dom0 + MicroVMs (hp, xmg)

A Qubes-like setup on NixOS: Xen dom0 with niri, the apps in MicroVMs
(microvm.nix fork, Xen PVH/HVM), driver domains for network and USB, Whonix
as image domains. Nix implementation: Lix. The plan, decisions and the work
log are in [xen-migration.md](xen-migration.md).

- Branch `hp` serves both machines, `main` is the old KVM setup of the xmg
  (fallback).
- microvm.nix fork: `github:23b00t/microvm.nix/xen` (flake input `microvm`),
  relay/RPC: `github:23b00t/NoX` (input `nox`).

## Machines

| | hp (test laptop) | xmg (main laptop) |
|---|---|---|
| CPU / RAM | AMD Ryzen 5 5500U 6C/12T, 32 GB | Intel i9 (Raptor Lake) 32 threads, 62 GB |
| dom0 | PVH, 8192 MB, 4 vCPUs, iGPU (amdgpu) | PVH, 6144 MB, 4 vCPUs, iGPU (i915) |
| sys-net | RTL8821CE WLAN `01:00.0` | RTL8125 Ethernet `05:00.0` (CNVi WLAN `00:14.3` not passed through yet) |
| sys-usb | both xHCI `03:00.3`, `03:00.4` | the only xHCI `00:14.0` |
| dGPU | – | NVIDIA RTX 5060 `02:00.0/.1` (for steam, not active yet) |
| dom0 internet | test phase: HTTPS/DNS/NTP via sys-net | none, updates only via the builder |
| extras | `machines/hp/dev-access.nix` (claude-code, LAN SSH, NOPASSWD for xl/microvm@/switching) | – |

### Firmware (xmg)

Check the installed version (no root, no `dmidecode` in dom0):

```sh
cat /sys/class/dmi/id/{bios_version,bios_date,product_name,board_name}
# 2026-10-15: N.1.21A10, 09/25/2025, XMG PRO (E25/M25), X6PR5xxW_X6RP5xxW
```

Updates (BIOS, EC, Intel ME) come from the XMG download portal, package
[XMG PRO 16 (E25) 13900HX / PRO 16 VE (M25) 14900HX](https://download.schenker-tech.de/package/xmg-pro-16-e25-xpr16e25-13900hx/)
(match the Product ID on the bottom label). They are flashed from the
EFI Shell on a FAT32 USB stick, no Windows needed; tools and PDF guide:
[BIOS Update via EFI Shell](https://download.schenker-tech.de/package/bios-update-via-efi-shell/),
background: [XMG help](https://help.xmg.gg/hc/en-gb/articles/17824611001117-How-can-I-update-the-EC-BIOS-firmware-of-my-laptop).
Follow the order in the package's readme (newer ME firmware needs a
minimum BIOS version). AC power connected, battery charged, don't touch
the machine while it flashes. Afterwards check the BIOS settings Xen
relies on (VT-d/VT-x, boot order) and the version again with the command
above.

## Repository layout

- `flake.nix`: composition; `nixosConfigurations.{hp,xmg}`, one
  `nixosConfigurations.<vm>` per VM definition.
- `vms/registry.nix`: single source of truth for VMs, image domains and the
  hardware of each machine. `forHost "<machine>"` is the view a machine
  gets: only VMs whose `hosts` contain it (no `hosts` = all machines,
  `hosts = [ ]` = definition kept, not built). Lookups by name
  (`byName`/`byShort`) cover all VMs.
- `vms/definitions.nix`, `vms/<name>/default.nix`: VM modules;
  `vms/modules/`: shared guest modules; `vms/store-groups.nix`: shared
  read-only store images per trust group (registry `storeGroup`).
- `machines/common-configuration.nix`: everything both machines share;
  `machines/xen-dom0.nix`: the Xen dom0; `machines/<machine>/`: hardware,
  machine specifics (`xen.nix`).
- `modules/`: dom0 modules (`xen-usb`, `xen-links`, `xen-memory`,
  `dom0-update`, `xen-image-domains`, `xen-vnc`, `dbus-proxy`).
- `home/`: home-manager for `nx`, VM tooling in `home/vm-management/`.

## Build and update

### Normal update (via the builder VM)

The builder VM (`10.0.0.25`) clones the repo from GitHub, builds only
commits signed by a key in `vms/builder/allowed-signers`, signs the closure
with its own key, and dom0 pulls it. Each machine has its own builder and
key (`vms/builder/signing-key-<machine>.pub`).

```sh
# commit + push first (signed), then on the machine:
dom0-update            # build + copy, switch-to-configuration boot
dom0-update --switch   # same, switch now
```

After a switch, VMs keep running with the old runner until restarted:
`manage-vms status` / `manage-vms restart --stale`.

### Full system update (new inputs + Whonix)

```sh
# in nvim, in the repo (clean tree):
flake-bump               # nix flake update (temporary store, removed afterwards),
                         # signed commit "update" + push after asking; flake-bump nixpkgs: one input
# then in dom0:
update-all               # dom0-update (boot), then Whonix-Gateway + -Workstation
update-all --switch      # same, switch dom0 now
```

`update-all` starts the Gateway/Workstation if they are off (and stops them
again afterwards), waits until sdwdate has synced over Tor, updates both
and offers a restart when a running one got a new kernel. Only rebuilding
dom0 without new inputs: `dom0-update`.

### First install of a machine (no builder yet)

```sh
cd ~/nixos-config && git fetch && git switch hp
sudo nixos-rebuild boot --flake .#<machine>
sudo bootctl list | grep -E 'title|version'   # "NixOS (with Xen Hypervisor)" is the default
systemctl reboot
```

Then set up the builder key:

```sh
sudo systemctl start microvm@builder
ssh 10.0.0.25 cat /var/lib/builder/signing-key.pub   # -> vms/builder/signing-key-<machine>.pub
# commit + push, then once more locally (dom0 needs internet for this):
sudo nixos-rebuild switch --flake .#<machine>
dom0-update --switch
```

Notes:
- dom0 has no git (the builder fetches from GitHub). For a local flake build
  in dom0 use `nix shell nixpkgs#git` first.
- New files must be tracked by git before a flake build sees them.
- microvm.nix creates volume images but never grows existing ones. If a VM
  runs out of space (e.g. the builder's `nix-store-overlay.img`, 100 GB),
  grow it with the VM stopped:
  ```sh
  sudo systemctl stop microvm@<vm>
  cd /var/lib/microvms/<vm>
  sudo truncate -s <size>M <image>.img && sudo e2fsck -f -y <image>.img && sudo resize2fs <image>.img
  sudo systemctl start microvm@<vm>
  ```
- The builder garbage-collects itself when it gets below 5 GB free.
- Never garbage-collect dom0 between copying a builder result and switching
  to it (the copied path is not a GC root until it is a generation).

### Rollback

Pick an older generation in the systemd-boot menu. On the xmg,
**generation 865** is the last KVM system (branch `main`). Don't pick the
plain "NixOS (Generation …)" entry of a Xen generation: it boots the new
config without the hypervisor, and no VM runs there.

One VM only (configuration): `nox rollback <vm>` lists the system
generations whose runner for that VM differs, `nox rollback <vm> --gen <n>`
makes that runner the VM's `current` and restarts it (a GC root keeps it),
`nox rollback <vm> --reset` goes back to the running system's runner. It
holds until a switch installs a changed runner for that VM. For good: revert
the VM's commit.

One VM (data): `nox snapshot <vm>` copies the stopped VM's images (sparse,
one snapshot per VM in `/var/lib/microvms/.snapshots`, space check first),
`nox rollback --data <vm>` puts them back. By hand only; `backup` stays the
backup.

One program: take it from an older nixpkgs, until the fix lands upstream.
Add a second input pinned to a good revision and an overlay in the VM's
module (or dom0's), then remove both again:

```nix
# flake.nix inputs
nixpkgs-good.url = "github:nixos/nixpkgs/<good-rev>";

# vms/<vm>/default.nix
nixpkgs.overlays = [
  (final: _: {
    termusic = inputs.nixpkgs-good.legacyPackages.${final.stdenv.hostPlatform.system}.termusic;
  })
];
```

`nox gc [--keep <n>] [-n]`: delete all but the newest n system generations
(default 3; `-n` only shows them), rewrite the boot menu, collect garbage.

## Managing VMs

### Our tools (dom0)

`nox` (NoX repo, `nox --help`, bash completion) is one command over the
scripts below: `nox` = running VMs, `nox list|start|stop|restart`,
`nox run|exec|ssh <vm> …`, `nox clip`, `nox copy`, `nox update [--all]`,
`nox usb …`, `nox disp [cmd…]` (ad-hoc disposable), `nox doctor` (smoke test of what runs: domains, SSH, relays,
network, RPC, clipboard, wprs, D-Bus, stale runners, disk, failed units,
new kernel/Xen errors), `nox rollback|snapshot|gc` (see Rollback).

| Command | What |
|---|---|
| `vm-run <vm> <app> [args]` | start a GUI app in a VM (wprs over vchan, app start over RPC) |
| `vm-run -c <vm> '<cmd>'` | run a command over SSH |
| `ssh <vm>` | SSH session (over the vchan relay socket); `<vm>`, `<vm>-vm`, the short alias or the IP, also for `whonix-gateway`, `whonix-workstation`. No host key check (guests make new host keys at every boot; the relay socket ties the connection to the domain), no warnings (`LogLevel ERROR`). |
| `manage-vms status [<vm>...] [--running] [--group <g>] [--stale]` | state of all VMs |
| `manage-vms <start\|stop\|restart> [<vm>...] [--running] [--group <g>] [--stale]` | single or bulk operations; a (re)started VM gets its tray apps (`vm-tray`); `ms`/`mst`/`mr <vm>...` are short for it |
| `manage-vms <start\|restart> --fresh <vm>...` (`nox restart --fresh`) | disposable VMs only: stop, set all their volume images aside (`/var/lib/microvms/<vm>/*.img.pre-fresh`, sudo asks for the password), start with empty ones. For a broken sys-net/sys-usb/sys-vpn state. Back: stop the VM, `sudo mv` the `.pre-fresh` files back, start it |
| `vm-disp [cmd…]` (`nox disp`) | start the ad-hoc disposable `disp` and open `cmd` in it (default foot); `nox stop disp` throws everything away |
| `vm-usb list` | USB devices in sys-usb and their owners |
| `vm-usb attach <device> <vm>` / `vm-usb detach <device>` | hand a USB device to a VM (USB/IP), device = busid, `vendor:product` or registry name |
| `vm-usb allow-input <busid>` | accept a new input device for dom0 until it is unplugged |
| `dom0-update [--switch]` | system update via the builder |
| `backup <dest> <vm>...` / `backup -a <dest>` / `backup -r <src>` | rsync of `/home/user` of VMs (not `/var`, not dom0) |
| `xen-image-setup <name>` | install the units into a stopped image domain (once per image, and again when the units change: 2026-10-18 added `nox-rpc-in` for dom0's fixed services — clip, app start, update-all — and `data/backend-ready`) |
| `xen-vnc <domain>` | display of an HVM domain with a stubdomain (Tails) |
| `sys-net-rescue` | sys-net doesn't come up: NICs back to dom0 |
| `sys-usb-rescue` | sys-usb doesn't come up: USB controllers back to dom0 (also automatic after 120 s) |
| `create-vm` | new VM |
| `nox copy [-m] [-n] [--max <bytes>] [<from-vm>] <to-vm> <path>…` | files over nox-rpc: from dom0, or from `<from-vm>` (paths relative to its home) when the first two arguments are VMs. dom0's own request needs no answer, except into a `warn` VM (vault: type its name). Lands in `~/Incoming/<source>` in the target, never overwrites (suffix), files and directories only (links dropped, `..` paths refused), at most what the sender announced and 10 GB. `-m` moves, `-n` shows what would be sent. Rules: registry `copy` (sys-* give nothing out, sys-print takes nothing, vault `warn`); never into dom0 |
| Mod+Alt+C / Mod+Alt+V (`vm-clip copy\|paste`) | clipboard between domains: copy the text clipboard of the focused window's VM (or dom0) into dom0's store, paste it into the focused window's VM (or dom0), then press Ctrl+V there; the store is emptied. VMs don't share their clipboard with dom0 otherwise. Copying out of vault asks, sys-* VMs are excluded (registry `clipboard`) |
| `vm-run <vm> foot [cmd…]` | terminal from a VM over wprs (dom0: `foot`, Mod+T). At login: one column with tabs dom0, nvim, coding (zellij in the VM; Mod+1…3), on the xmg irc on "remote"; kitty and zellij are gone from dom0 (zellij stays on the hp) |

In the VMs: `vm-copy [-m] [-n] <vm> <files>` (dom0 asks in a rofi dialog with the
size and names, files land in `~/Incoming/<source>`; the old `cp-vm` over
the vmcopy account is gone), `vm-print <printer-ip> <file>` (via sys-print).

### systemd units

```sh
sudo systemctl start|stop|restart microvm@<vm>          # MicroVMs
sudo systemctl start|stop|restart xen-image@<name>      # Whonix image domains
journalctl -b -u microvm@<vm>                           # VM start/stop
journalctl -b -u xen-input-proxy -u vm-usb-auto -u xen-links
journalctl -b -u nox-relay-<vm>                         # vchan relay
systemctl --user status wprsd                           # (in the VM) GUI server
journalctl -b -u nox-sys-ready                          # boot order barrier
```

Boot order: the driver domains in `microvm.autostart` (sys-*) and the
Whonix-Gateway (if it autostarts) start first, in parallel; every other
domain waits for `nox-sys.target`, which is reached once each of them is
booted (`/run/nox-relay/<name>.ready` exists while its relay is connected),
at most 120 s, then the rest starts anyway (`nox-sys-ready` logs who was
missing). Started by hand later, a VM doesn't wait (the target is already
reached).

### Xen (`xl`)

```sh
sudo xl info | grep -E 'total_memory|free_memory|nr_cpus|xen_version'   # whole machine
sudo xl list                     # domains with RAM (MB) and vCPUs
sudo xl top                      # live CPU/RAM per domain (xentop), q to quit
sudo xl vcpu-list                # which vCPU runs on which physical CPU
sudo xl uptime
sudo xl mem-set <domain> <MB>    # change a domain's RAM (the balancer does this for ballooning VMs)
sudo xl console <domain>         # serial console, leave with Ctrl+]
sudo xl network-list <domain>    # vifs and their backend domains
sudo xl pci-assignable-list      # devices held by pciback
sudo xl dmesg | tail -50         # hypervisor log
sudo xl destroy <domain>         # hard stop (only if the unit can't stop it)
```

Logs: `/var/log/xen/console/guest-<domain>.log`, `/var/log/xen/xl-<domain>.log`,
`/var/log/xen/xen-hotplug.log`.

### RAM

dom0 keeps its memory (hp 8192 MB, xmg 6144 MB; `autoballoon="off"`). VMs with `balloon = true`
boot with `initialBalloonMem` and the RAM balancer
(`modules/xen-memory.nix`) grows them up to `mem` as free Xen memory
allows (registry `memPriority`: higher grows first). VMs with PCI
passthrough (sys-net, sys-usb, steam) have fixed memory.

## Networking

- `vm-internal`: admin bridge in dom0 (`10.0.0.254`), every VM port
  isolated, VM `10.0.0.<index>`; SSH to the VMs goes over the vchan relay.
- `vm-uplink` in sys-net (`10.1.0.254/24`): internet for VMs with
  `nat = true` (`10.1.0.<index>`), NAT to the physical NIC, VMs can't reach
  each other or dom0.
- `vm-usbip` in sys-usb (`10.2.0.254/24`): USB/IP to the VMs that own USB
  devices.
- `vm-whx-ext` in sys-net (`10.0.2.2/24`): outside of the Whonix-Gateway
  only. `eth1` inside the gateway (`10.152.152.10/18`): irc and the
  Workstation, so sys-net only ever sees Tor traffic.
- `vm-tails` in sys-net (`10.3.0.1/24`, DHCP): Tails only.
- `vm-vpn` in sys-vpn (`10.4.0.254/24`): uplink of VMs with registry
  `uplink = "sys-vpn"` (`10.4.0.<index>`), only through the VPN tunnel
  (see "sys-vpn (VPN)").
- vifs are re-attached by `xen-links` when a driver domain restarts.
- Never remove the dom0 networkd rule that leaves `vnet*` unmanaged.

### sys-net on the xmg (RTL8125): what it took

The first Xen boot of the xmg (2026-10-11) had working downloads but
uploads from VMs at 20–66 KB/s, stalled Tor circuits (Whonix) and a
builder that hung on cache.nixos.org. Several separate causes, found and
fixed one at a time (details in `xen-migration.md`, Known Issues):

| Step | Finding | Fix |
|---|---|---|
| Builder narinfo storm | HTTP/2 multiplexing in Nix stalled all cache requests over sys-net | `nix.settings.http2 = false` in `vms/builder` (`5c5c0e5`) |
| MSI under PVH dom0 | no network with MSI; INTx (`pci=nomsi`) worked | back to `pci=nomsi` (`470345a`) |
| sys-net restart | the old domain stayed (`---s--`) and held the card; `xl destroy` failed at `unmap_gsi` | `ExecStartPre` destroys a leftover domain (`470345a`); GSI 18 freed: dGPU to pciback at boot, SMBus without IRQ (`4b09b5d`). Fully fixed only with the PV dom0 |
| Tor/Whonix hangs | multi-queue vifs between backends with >1 vCPU and Debian guests left connections stuck | `xen_netback max_queues=1` in driver domains (`7ca26e1`) |
| Upload ~100× too slow | INTx passthrough under a PVH dom0 | PV dom0 (`hostProfile.dom0Pv`, `dom0=pv`, `f1b3a58`) |
| Forwarded uploads ~20 KB/s | r8169 TX checksum offload broke NATed packets (sys-net itself was fine) | `.link` in sys-net: TX checksum/SG/TSO/GSO off (`a022e56`); VMs at ~4.9 MB/s |
| MSI under PV dom0 | works (MSI-X; hp WLAN: MSI too), Xen has interrupt remapping (`xl dmesg`: `Interrupt remapping enabled`), so passthrough with MSI is safe | test flag (`95efe99`), then the default for driver domains (sys-net, sys-usb) with a PV dom0: `pci=nomsi` only under PVH |

`ip -s link` in sys-net shows a few % RX `dropped` on `ens3`: these are
broadcasts with protocols sys-net does not speak (`ethtool -S ens3`: no
error counters, `missed` 0), not lost packets.

Useful checks: `xl dmesg | grep -i remap`, in sys-net
`grep ens3 /proc/interrupts` (`PCI-MSIX` vs `IO-APIC`), `ethtool -S ens3`,
`ethtool -k ens3`, `xl network-list <vm>` (`ring-ref -1/-1` = multi-queue),
upload test from a VM against speed.cloudflare.com.

## USB

sys-usb owns the USB controllers. Input devices with owner `host` in the
registry (`hardware.usb`) come back to dom0 over the input proxy
(`xen-input-proxy`), other owners get the device over USB/IP
(`vm-usb-auto` applies the `defaultOwner`). The LUKS passphrase can be
typed on a USB keyboard (dom0 still owns the controller in the initrd);
the internal keyboard and touchpad are not on USB.

## VMs per machine

| VM | hp | xmg | notes |
|---|---|---|---|
| sys-net, sys-usb | ✓ | ✓ | HVM driver domains, disposable: only data volumes stay (NetworkManager profiles, Bluetooth pairings) |
| nvim, coding, chat, net, office, vault | ✓ | ✓ | |
| irc | ✓ | ✓ | only uplink: Whonix-Gateway |
| builder, sys-print | ✓ | ✓ | |
| sys-vpn | ✓ | ✓ | VPN driver domain with killswitch for VMs with registry `uplink = "sys-vpn"` |
| vanilla | ✓ | ✓ | only common-config, software imperatively in the store overlay; uplink via sys-vpn (test) |
| disp, disp-backup | ✓ | ✓ | disposables (registry `disposable`): empty on every start; disp = vanilla setup for ad-hoc work (`nox disp`), disp-backup = backup disk holder (no network) |
| php, ruby | | ✓ | |
| whonix-gateway, whonix-workstation | ✓ | ✓ | image domains |
| win | ✓ | ✓ | Windows apps via Bottles (replaces wine) |
| kali | | ✓ | image domain (Kali QEMU image), lab bridge for Burp against `labTarget` VMs |
| steam, godot, mirage, nix | | | definitions kept (`hosts = [ ]`); steam prepared for the xmg |

### New VM

Use `create-vm` or the `new-vm` Claude skill; keep `vms/registry.nix`,
`vms/definitions.nix` and `vms/<name>/default.nix` consistent (markers
`# create-vm: registry-vms` and `# create-vm: definitions`). Host SSH key:
`ssh-keygen -t ed25519 -N "" -C <vm>-vm -f ~/.ssh/<vm>-vm`, public key into
the registry (`hostSSHKey`).

### Additional setup for IDE VMs

```sh
scp privat.asc public.asc <vm>-vm:   # from dom0, then in the VM:
gpg --import privat.asc && gpg --import public.asc
chmod 700 ~/.gnupg && chmod 600 ~/.gnupg/*
gpg --edit-key <KEY-ID>                # trust, 5, y, quit
gh auth login
```

Export from the source: `gpg --list-secret-keys --keyid-format LONG`,
`gpg --export-secret-keys <id> > privat.asc`, `gpg --export <id> > public.asc`.

## Whonix (from scratch)

Gateway (CLI image) and Workstation (LXQt image) run as PVH image domains
from the upstream images (`modules/xen-image-domains.nix`, domains in
`machines/xen-dom0.nix`): pvgrub2 boots the Debian kernel of the guest, a
read-only store disk brings nox-relay, sshd (and wprsd for the
Workstation). The images live in `~/vm-images/whonix/`.

### 1. Download and verify

Check the current version on whonix.org first.

```sh
V=18.2.1.9
D=~/vm-images/whonix
B=https://www.whonix.org/download/libvirt/$V
FPR=916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA
mkdir -p "$D" && cd "$D"
export GNUPGHOME="$D/gnupg"; mkdir -p -m 700 "$GNUPGHOME"
curl -fsSL -o derivative.asc https://www.whonix.org/keys/derivative.asc
gpg --batch --import derivative.asc
gpg --batch --with-colons --fingerprint | grep -q "^fpr:::::::::$FPR:" && echo "key ok"
for f in Whonix-CLI-$V.Intel_AMD64.qcow2.libvirt.xz Whonix-LXQt-$V.Intel_AMD64.qcow2.libvirt.xz; do
  curl -fSL -C - -o "$f" "$B/$f"
  curl -fsSL -o "$f.asc" "$B/$f.asc"
  gpg --batch --status-fd 1 --verify "$f.asc" "$f" | grep -qE "VALIDSIG .*$FPR" && echo "OK $f" || echo "BAD SIGNATURE $f"
done
```

### 2. Unpack and convert to raw

```sh
cd ~/vm-images/whonix
mkdir -p cli lxqt
tar -C cli -xJf Whonix-CLI-$V.Intel_AMD64.qcow2.libvirt.xz
tar -C lxqt -xJf Whonix-LXQt-$V.Intel_AMD64.qcow2.libvirt.xz --wildcards '*Workstation*'
nix shell nixpkgs#qemu-utils -c qemu-img convert -p -O raw -S 4k cli/Whonix-Gateway-CLI-$V.Intel_AMD64.qcow2 whonix-gateway.raw
nix shell nixpkgs#qemu-utils -c qemu-img convert -p -O raw -S 4k lxqt/Whonix-Workstation-LXQt-$V.Intel_AMD64.qcow2 whonix-workstation.raw
nix shell nixpkgs#util-linux -c sfdisk -l whonix-gateway.raw   # root = partition 3 (rootPartition in the config)
rm -rf cli lxqt
```

The raw images are 100 GB sparse (~4 and ~7 GB used). Copy them with
`tar -S`, not `rsync --sparse` (rsync reads and sends the holes):
`ssh <host> 'tar -cS -C vm-images/whonix whonix-gateway.raw whonix-workstation.raw | zstd -T0 -3' | zstd -d | tar -xS -C ~/vm-images/whonix`.

### 3. SSH keys

```sh
ssh-keygen -t ed25519 -N "" -C whonix-gateway-vm -f ~/.ssh/whonix-gateway-vm
ssh-keygen -t ed25519 -N "" -C whonix-workstation-vm -f ~/.ssh/whonix-workstation-vm
```

Public keys into `imageDomains` in `vms/registry.nix` (`hostSSHKey`),
commit, `dom0-update --switch`. The keys are on the store disk, no new
setup needed when they change.

### 4. Install the units (once per image, domain stopped)

```sh
sudo systemctl stop xen-image@whonix-gateway xen-image@whonix-workstation
xen-image-setup whonix-gateway
xen-image-setup whonix-workstation
```

### 5. Enable Tor in the Gateway

Whonix only enables Tor's network with `DisableNetwork 0` (normally set by
its setup wizard). Keep this line in `50_user.conf` whenever you edit it.

```sh
sudo systemctl start xen-image@whonix-gateway
ssh whonix-gateway-vm
sudo nano /usr/local/etc/torrc.d/50_user.conf
#   DisableNetwork 0
#   MapAddress guybrush.hackint.org dtlbunzs5b7s5sl775quwezleyeplxzicdoh3cnhm7feolxmkfd42nqd.onion
#   MapAddress palladium.libera.chat libera75jm6of4wxpxt4aynol3xjmbtxgfyjpu34ss4d7r7q2v5zrpyd.onion
sudo systemctl restart tor@default
sudo journalctl -u tor@default -f        # wait for "Bootstrapped 100% (done)"
```

The `MapAddress` lines send irc's IRC servers to their onion services.

### 6. Use

```sh
sudo systemctl start microvm@irc
vm-run -c i 'curl -sS https://check.torproject.org/api/ip'   # "IsTor":true
sudo systemctl start xen-image@whonix-workstation
vm-run ww torbrowser          # or the desktop entry "torbrowser whonix"
```

Tor Browser settings that wprs needs or that you want:

- **Scrolling** doesn't work over wprs with smooth scrolling on: open
  `about:config`, set `general.smoothScroll` to `false`.
- **Dark:** Settings → Extensions & Themes → Themes → "Dark" (browser UI);
  Settings → General → Website appearance → "Dark". Tor Browser may still
  report a light preference to websites (fingerprinting protection).

**Updates:** `dom0-update` only renews the store disk (nox-relay, sshd, wprsd), not the Debian system inside the images. Gateway: `update-all` (see 7.), or by hand `ssh -t whonix-gateway-vm upgrade-nonroot` (Whonix 18: `sudo apt-get --update full-upgrade`; `apt-get-update-plus` is gone). Workstation: `sudo` and `upgrade-nonroot` only work in the sysmaint session (Kicksecure user/sysmaint split); `update-all` boots it once (`/run/xen-image/whonix-workstation.sysmaint`) and logs in as `sysmaint`. Over SSH only the account of the running session may log in (`user` in the normal session, `sysmaint` in the sysmaint session). New Debian kernels just work (pvgrub reads the guest's grub.cfg).

The Workstation's firewall stays closed until `sdwdate` has synced the time
over Tor once (`/run/sdwdate/first_success`). Start it after the Gateway's
Tor is up; if it has no network, restart it:
`sudo systemctl restart xen-image@whonix-workstation`.

On the xmg the Gateway and irc start at boot. Debian guests may lack foot's
terminfo (Backspace etc. broken over SSH): `TERM=xterm-256color ssh …`.

`xen-image@whonix-gateway` waits (up to 90 s) until sys-net reports a
default route (`data/uplink` in its xenstore). Tor started without an
uplink marks its guards unreachable and stays stuck; if that still
happens, restart the Gateway.

### 7. Gateway commands

From the Whonix wiki (Tor, Tor Controller, Bridges), run in
`ssh whonix-gateway-vm`; not all tried here yet.

```sh
tor-ctrl signal NEWNYM                  # new circuits for new connections ("250 OK")
nyx                                     # live monitor: bandwidth, circuits, log; n = new circuit, q q = quit
sudo anon-log                           # Tor log, filtered
sudo journalctl -f -b --output cat -u tor -u tor@default -u vanguards
sudo systemctl status tor@default       # state of the daemon
tor-prompt --no-color --run "getinfo status/bootstrap-phase"
systemcheck --verbose --leak-tests      # Whonix self test
sudo systemctl restart tor@default      # after editing torrc
sudo -u debian-tor tor --verify-config  # check torrc before restarting
```

**Bridges** (if Tor is blocked): add to
`/usr/local/etc/torrc.d/50_user.conf` (`sudoedit`, keep `DisableNetwork 0`),
then restart Tor:

```
UseBridges 1
ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy
Bridge obfs4 <IP>:<PORT> <FINGERPRINT> cert=<CERT> iat-mode=0
```

Bridge lines from bridges.torproject.org. Snowflake
(`ClientTransportPlugin snowflake exec /usr/bin/snowflake-client`) also
needs DNS outside Tor: the wiki uncomments `nameserver 10.0.2.3` in
`/etc/resolv.conf.whonix`; here the outside gateway is sys-net (`10.0.2.2`),
which serves no DNS on `vm-whx-ext` yet, so snowflake does not work as is.

**Update:** `update-all` (see "Full system update" under Build and update)
updates both images with `upgrade-nonroot` (Gateway and
Workstation).

## Kali (from scratch)

Kali runs on the xmg as a PVH image domain from the official QEMU image
(domain in `machines/xmg/xen.nix`), like the Whonix-Workstation: pvgrub2
boots Kali's kernel, the store disk brings nox-relay, sshd and wprsd. Apps
over wprs (`vm-run k burpsuite`), updates with apt (`update-all`). The
image domain integration expects the user `user` (UID 1000): Kali's `kali`
is renamed once, offline.

Network: first vif on sys-net's `vm-uplink` (10.1.0.8, internet), second
vif on the lab bridge `vm-lab` (10.5.0.8). VMs with registry `labTarget`
(php, coding) join the lab only on demand: `vm-lab attach <vm>`
(10.5.0.<last octet of the VM's IP>), `vm-lab detach <vm>`, `vm-lab status`.
In the lab only kali talks to the targets, the targets never reach each
other; nothing is routed in or out.

### 1. Download, verify, convert (in a VM with internet and ~40 GB free, e.g. coding)

dom0 is offline. Check the current version on kali.org first.

```sh
V=2026.2
B=https://cdimage.kali.org/kali-$V
FPR=827C8569F2518CC677FECA1AED65462EC8D5E4C5
mkdir -p ~/kali && cd ~/kali
export GNUPGHOME="$PWD/gnupg"; mkdir -p -m 700 "$GNUPGHOME"
curl -fsSL https://archive.kali.org/archive-key.asc | gpg --batch --import
gpg --batch --with-colons --fingerprint | grep -q "^fpr:::::::::$FPR:" && echo "key ok"
f=kali-linux-$V-qemu-amd64.7z
curl -fSL -C - -O "$B/$f"
curl -fsSL -O "$B/SHA256SUMS" -O "$B/SHA256SUMS.gpg"
gpg --batch --status-fd 1 --verify SHA256SUMS.gpg SHA256SUMS | grep -qE "VALIDSIG .*$FPR" && echo "sums ok"
grep " $f\$" SHA256SUMS | sha256sum -c -
nix shell nixpkgs#p7zip -c 7z e "$f" && rm "$f"
nix shell nixpkgs#qemu-utils -c qemu-img convert -p -O raw -S 4k kali-linux-$V-qemu-amd64.qcow2 kali.raw
rm kali-linux-$V-qemu-amd64.qcow2
nix shell nixpkgs#util-linux -c sfdisk -l kali.raw   # root partition -> rootPartition in machines/xmg/xen.nix
```

Into dom0 (sparse, as for Whonix):

```sh
mkdir -p ~/vm-images/kali
ssh coding-vm 'tar -cS -C kali kali.raw | zstd -T0 -3' | zstd -d | tar -xS -C ~/vm-images/kali
ssh coding-vm 'rm -rf kali'
```

### 2. Prepare the image (dom0, once, domain stopped)

Rename `kali` to `user`, set its password, boot to multi-user (no display
manager) and add the NetworkManager profiles (matched by MAC).

```sh
cd ~/vm-images/kali
P=1   # root partition from sfdisk -l
start=$(sfdisk -d kali.raw | sed -n "s/^kali.raw$P : start= *\([0-9]*\),.*/\1/p")
sudo mkdir -p /mnt/kali
sudo mount -o loop,offset=$((start * 512)) kali.raw /mnt/kali
sudo usermod -R /mnt/kali -l user -d /home/user -m kali
sudo groupmod -R /mnt/kali -n user kali
sudo chpasswd -R /mnt/kali <<< 'user:<new password>'
sudo ln -sf /lib/systemd/system/multi-user.target /mnt/kali/etc/systemd/system/default.target
sudo tee /mnt/kali/etc/NetworkManager/system-connections/uplink.nmconnection >/dev/null <<'EOF'
[connection]
id=uplink
type=ethernet
autoconnect=true

[ethernet]
mac-address=00:00:00:00:01:08

[ipv4]
method=manual
address1=10.1.0.8/24,10.1.0.254
dns=9.9.9.9;149.112.112.112;

[ipv6]
method=disabled
EOF
sudo tee /mnt/kali/etc/NetworkManager/system-connections/lab.nmconnection >/dev/null <<'EOF'
[connection]
id=lab
type=ethernet
autoconnect=true

[ethernet]
mac-address=00:00:00:00:03:08

[ipv4]
method=manual
address1=10.5.0.8/24
never-default=true

[ipv6]
method=disabled
EOF
sudo chmod 600 /mnt/kali/etc/NetworkManager/system-connections/*.nmconnection
sudo umount /mnt/kali
```

### 3. SSH key, units

The key `~/.ssh/kali-vm` (from the former NixOS kali) is in the registry
already. Only on a machine without it: `ssh-keygen -t ed25519 -N "" -C
kali-vm -f ~/.ssh/kali-vm` and put the public key into `imageDomains` in
`vms/registry.nix`. After `dom0-update --switch`:

```sh
xen-image-setup kali
```

### 4. Use

```sh
sudo systemctl start xen-image@kali
vm-run -c k 'ip -br addr; curl -sS https://ifconfig.me'
vm-lab attach php             # php reachable from kali at 10.5.0.15
vm-run k burpsuite            # proxy listener 127.0.0.1:8080
vm-run k firefox-esr          # proxy 127.0.0.1:8080, import Burp's CA (http://burp)
#   target e.g. http://10.5.0.15:8500 (the app must listen on 0.0.0.0)
vm-lab detach php
```

If the domain does not come up: `sudo xl console kali-vm` (Kali's kernel
needs `CONFIG_XEN_PVH`; fallback would be HVM with a stubdomain like Tails).

## win (Windows apps)

Windows apps run under Wine in Bottles, one bottle (prefix) per app, and
show up in dom0 over wprs like any other VM app. No GPU: rendering is in
software (fine for tools and Office, not for games; those go to steam).
win has internet but no browser; `vm-run` starts the VM if it is off.

### Install an app

1. Get the installer into win, either from net (`vm-copy win setup.exe` in
   net, dom0 asks, it lands in `~/Incoming/net/` in win) or directly:
   `vm-run -c w 'mkdir -p ~/Installers && curl -fL -o ~/Installers/setup.exe <url>'`.
2. `vm-run w bottles` (or the desktop entry "bottles win"). First start:
   Bottles downloads its runners and components.
3. Create a bottle: environment "Application" (64-bit, sensible defaults)
   for most tools; "Custom" with architecture 32-bit for 32-bit apps such
   as Office 2016/2019 32-bit. Runner: the default (soda/caffe, wine-staging
   based); for a problem case try another one under Preferences → Runners
   (e.g. a Proton-GE build) and switch it in the bottle's settings.
4. In the bottle: Dependencies → install what the app needs (e.g.
   `vcredist2019`, `dotnet48`, for Office `msxml6`, `riched20`, `gdiplus`).
5. "Run Executable…" → pick the installer from `~/Incoming/net/` or
   `~/Installers/`. Installed programs appear under the bottle's Programs;
   for a portable `.exe` use "Add Shortcuts…".

The bottle's C: drive is `~/.local/share/bottles/bottles/<bottle>/drive_c`
in win, the home directory is reachable as Z:. Unknown apps: give each its
own bottle and delete the bottle when the app is not kept.

### Use an app over wprs

```sh
vm-run w bottles-cli programs -b <bottle>                # program names
vm-run w bottles-cli run -b <bottle> -p '<program>'      # start by name
vm-run w bottles-cli run -b <bottle> -e /home/user/Installers/tool.exe   # a .exe by path
```

For a permanent launcher in dom0 add an entry to
`home/vm-management/desktop-entries.nix`:

```nix
(mkVmEntry {
  name = "notepad++ win";
  vm = "win";
  binary = "bottles-cli";
  args = "run -b notepadpp -p Notepad++";
  icon = "wine";
  categories = [ "Utility" ];
})
```

winetricks outside Bottles works on a bottle's prefix as well:
`vm-run -c w 'WINEPREFIX=~/.local/share/bottles/bottles/<bottle> winetricks <verb>'`.

## sys-vpn (VPN)

sys-vpn is a driver domain like the Whonix-Gateway: client VMs get their
uplink from it (bridge `vm-vpn`, `10.4.0.<index>`, gateway and DNS
`10.4.0.254`), sys-vpn itself goes out through sys-net. NetworkManager in
sys-vpn runs the tunnel; the provider config lives on its volume
(`/etc/NetworkManager/system-connections`), never in the repo.

- **Killswitch:** clients are only forwarded into tunnel interfaces
  (`wg*`, `tun*`), everything else is rejected. Without a tunnel the
  clients have neither internet nor DNS.
- **DNS:** dnsmasq in sys-vpn forwards only to the tunnel's DNS server
  (written to `/run/sys-vpn/dns-servers` by an NM dispatcher on tunnel
  up, emptied on down).
- Clients are IPv4 only; they can't reach each other.

### Set up a provider (Proton VPN, WireGuard)

WireGuard is preferred: NetworkManager imports the config as is, no extra
credentials (OpenVPN would need Proton's OpenVPN username/password and
`networkmanager-openvpn`, which is installed).

1. In net: account.protonvpn.com → Downloads → WireGuard configuration,
   platform GNU/Linux, pick a server, create and download.
2. **Rename the file to `wg-<name>.conf`** (e.g. `wg-proton.conf`, at
   most 15 characters): NetworkManager names the interface after the file,
   and the killswitch only forwards into `wg*`/`tun*`.
3. Still in net: `vm-copy sys-vpn ~/Downloads/wg-proton.conf` (dom0
   asks); it lands in `~/Incoming/net/` in sys-vpn.
4. In sys-vpn (`ssh sys-vpn`):

   ```sh
   sudo nmcli connection import type wireguard file ~/Incoming/net/wg-proton.conf
   sudo nmcli connection modify wg-proton connection.autoconnect yes
   nmcli connection up wg-proton
   ip -br link | grep wg               # wg-proton UP
   cat /run/sys-vpn/dns-servers        # server=10.2.0.1@wg-proton
   rm ~/Incoming/net/wg-proton.conf    # holds the private key
   ```

   Further servers: the same with another `wg-<name>.conf`; only one
   tunnel should be up at a time.

Note: Proton's tunnel uses `10.2.0.0/24` (DNS `10.2.0.1`), the same range
as our `vm-usbip`. That does not matter for the clients (they only talk to
`10.4.0.254`), but don't route `10.2.0.x` through sys-vpn.

### Use

- A VM goes through the VPN with `uplink = "sys-vpn"` (and `nat = true`)
  in `vms/registry.nix`, then rebuild and restart the VM. Starting it
  also starts sys-vpn (vanilla is the first client).
- Check in the client: `curl -s https://ifconfig.me` shows the VPN's IP.
- Tunnel in sys-vpn: `nmcli connection show --active`,
  `nmcli connection down|up wg-proton`. With the tunnel down, clients
  are offline; names they resolved before may still answer from their
  own cache (`resolvectl flush-caches` in the client).
- Switching server: `nmcli connection down wg-proton` and `up` another
  `wg-…` connection.

## sys-print (printing)

sys-print is a small VM without user data that prints for the other VMs.
A VM sends a document with `vm-print <printer-ip> <file>`; dom0 asks
(rofi: Allow/Deny); sys-print hands it to CUPS, which talks to the printer
over IPP. office and coding themselves have no CUPS; office has no network
at all. sys-net lets sys-print reach only private addresses on TCP 631
(IPP), nothing else, no internet.

- **Printer requirement:** driverless IPP ("IPP Everywhere"). Practically
  every network printer that supports AirPrint or Mopria can do it. No
  drivers, no PPDs.
- **Same network:** the printer must be in the network sys-net is
  connected to (same WLAN/router). A printer that only offers its own
  hotspot ("Wi-Fi Direct") works only if sys-net joins that hotspot,
  and then there is no internet while printing.
- sys-print runs only when needed: `nox start sys-print` before
  printing, `nox stop sys-print` afterwards. It is not started for you.

### Set up a WLAN printer (once per printer)

1. **Printer into the WLAN:** on the printer's display (network/Wi-Fi
   setup wizard) choose the same WLAN as sys-net and enter the password.
   Printers without a display: WPS button on the router and the printer,
   or the vendor's setup instructions.
2. **Find its IP address:** on the printer's display (network status /
   Wi-Fi details) or print a network configuration page (usually in the
   printer's menu, often a long press on the Wi-Fi or info button). As an
   alternative, the router's list of connected devices. Note the IPv4
   address, e.g. `192.168.1.57`. Best: give the printer a fixed address in
   the router (DHCP reservation), otherwise it may change next time.
3. **Check the printer speaks IPP** (dom0):

   ```sh
   nox start sys-print
   vm-run -c sys-print ipptool -tv ipp://192.168.1.57/ipp/print get-printer-attributes.test | head -20
   ```

   Expected: `[PASS]` and attributes like `printer-make-and-model`. With
   `Connection refused` or a timeout: wrong address, printer not in the
   same network, or IPP switched off in the printer's web interface
   (open `http://192.168.1.57` in net and enable IPP / AirPrint).

There is nothing to configure in sys-print: the first print job to an
address creates the queue (`ipp-192-168-1-57`) on its own.

### Print from office

office has no print dialog that reaches the printer (no CUPS there). The
way is: save as PDF, send the PDF.

1. `nox start sys-print` (dom0).
2. In the office app make a PDF:
   - LibreOffice: File → Export as PDF… → Export, e.g. to
     `~/Documents/letter.pdf`.
   - A PDF you already have (e.g. from `~/Incoming/…`) can be sent as is.
3. Open a terminal in office: `vm-run office foot` (dom0), then in it:

   ```sh
   vm-print 192.168.1.57 ~/Documents/letter.pdf
   ```

4. dom0 shows a rofi question "print?" with office as the source: choose
   **Allow**. Deny or no answer within 30 s cancels the job.
5. The terminal shows `ok: request id is ipp-192-168-1-57-1 (1 file(s))`
   and the printer starts. An `error: …` line says what went wrong (wrong
   address, no IPP printer there).
6. `nox stop sys-print` when done.

Besides PDF, `vm-print` takes PostScript, images (PNG/JPEG) and plain
text; CUPS converts them.

### Test from coding

Same as from office, with a text file:

```sh
nox start sys-print                       # dom0
vm-run coding foot                        # dom0: terminal in coding
echo "test print from coding $(date)" > ~/print-test.txt   # in coding
vm-print 192.168.1.57 ~/print-test.txt                       # in coding
```

Allow in dom0's question; a page with the line comes out. Status of the
jobs (dom0): `vm-run -c sys-print lpstat -o` (waiting jobs),
`vm-run -c sys-print lpstat -W completed -o` (done ones).

## Tails (HVM with a Linux stubdomain)

Tested on the hp (2026-10-10), not set up permanently on any machine. Tails
runs as HVM; qemu runs in a Linux stubdomain (package `xen-stubdom-linux`
from the microvm.nix fork), the display comes over vchan as VNC
(`modules/xen-vnc.nix`). Tails only boots and keeps its Persistent Storage
on a removable drive, so qemu emulates a USB stick.

Needed in the config (already there): bridge `vm-tails` with DHCP in
sys-net, `services.xen-vnc.domains = [ "tails" ];` (set in
`machines/hp/xen.nix`; add it to `machines/xmg/xen.nix` for the xmg).

### 1. Download and verify

Current version and links: https://tails.net/install/download/ (USB image
`.img`, its `.sig`, signing key `tails-signing.key`).

```sh
T=7.14
mkdir -p ~/vm-images/tails && cd ~/vm-images/tails
curl -fSLO https://download.tails.net/tails/stable/tails-amd64-$T/tails-amd64-$T.img
curl -fSLO https://tails.net/torrents/files/tails-amd64-$T.img.sig
curl -fSLO https://tails.net/tails-signing.key
export GNUPGHOME=$PWD/gnupg; mkdir -p -m 700 "$GNUPGHOME"
gpg --import tails-signing.key
gpg --verify tails-amd64-$T.img.sig tails-amd64-$T.img   # primary key A490 D0F4 D311 A415 3E2B B7CA DBB8 02B2 58AC D84F
```

### 2. Stick image and stubdomain

```sh
cd ~/vm-images/tails
cp tails-amd64-$T.img tails.raw && truncate -s 8G tails.raw    # >= 8 GB: 4 GB system + 4 GB Persistent Storage
nix build github:23b00t/microvm.nix/xen#xen-stubdom-linux --out-link stubdom-gcroot
# (dom0 without internet: build it in the builder and `nix copy --from ssh-ng://10.0.0.25 <path>`)
```

### 3. `~/vm-images/tails/tails.cfg`

```
name = "tails"
type = "hvm"
memory = 3072
vcpus = 2
device_model_version = "qemu-xen"
device_model_stubdomain_override = 1
stubdomain_kernel = "/home/nx/vm-images/tails/stubdom-gcroot/qemu-stubdom-linux-kernel"
stubdomain_ramdisk = "/home/nx/vm-images/tails/stubdom-gcroot/qemu-stubdom-linux-rootfs"
stubdomain_memory = 256
vnc = 0
device_model_args_pv = [ "-serial", "null", "-serial", "null", "-serial", "null" ]
boot = "c"
on_poweroff = "destroy"
on_reboot = "destroy"
on_crash = "destroy"
vif = [ "mac=00:00:00:00:03:01, bridge=vm-tails, backend=sys-net-vm" ]
# The image as a removable USB stick served by qemu in the stubdomain.
# xvde: beyond the 4 emulated IDE slots; xen_platform_pci = 0: no second
# path over PV blkfront; usb-tablet: absolute pointer for VNC clicks
xen_platform_pci = 0
device_model_args_hvm = [ "-vnc", "unix:/tmp/vnc.sock", "-device", "qemu-xhci,id=xhci", "-drive", "if=none,id=tailsusb,format=raw,file=/dev/xvde", "-device", "usb-storage,bus=xhci.0,drive=tailsusb,removable=on,bootindex=0", "-device", "usb-tablet,bus=xhci.0" ]
disk = [ "format=raw, vdev=xvde, access=rw, target=/home/nx/vm-images/tails/tails.raw" ]
```

Tails needs 3 GB RAM ("Insufficient memory" with 2 GB). The three
`-serial null` are required, otherwise qemu fails with `No serial device #2`.

### 4. Run

```sh
sudo xl create ~/vm-images/tails/tails.cfg
xen-vnc tails                  # Greeter -> Start Tails -> Connect to Tor
sudo xl shutdown -F tails      # ACPI (no PV drivers); or shut down inside Tails, xl destroy tails if it hangs
```

Network comes by DHCP from `vm-tails` (`10.3.0.1xx`). A fresh stick:
repeat the `cp`/`truncate` step.

## steam (prepared, not active)

`vms/steam/default.nix` is ready for Xen on the xmg: HVM with the NVIDIA
dGPU (`02:00.0`, `02:00.1`) passed through, `pci_permissive`,
in its own cpupool `steam` (dom0 moves the P-core threads 0–15 there while
steam runs, everything else keeps the E-cores 16–31; `machines/xmg/xen.nix`),
16 GB fixed RAM, gamescope on the dGPU's HDMI output as before.
Keyboard, mouse and the Bluetooth adapter come over USB/IP
(`vm-usb attach keyboard-atreus steam`, `mouse-main`, `bluetooth-ax211`).
Enable with `hosts = [ "xmg" ]` in the registry. The existing
`/var/lib/microvms/steam/home.img` is reused.

## Known issues

Known issues and their status are tracked in
[xen-migration.md](xen-migration.md#known-issues). Machine specifics:

- **hp: touchpad dead under PVH dom0** (AMD GPIO controller gets no
  interrupt: `amd_gpio AMDI0030:00: error -EINVAL: IRQ index 0 not found`).
  Works with a PV dom0 (`dom0=pv` instead of `dom0=pvh` in
  `virtualisation.xen.boot.params`). PVH stays the target; if dom0 hardware
  misbehaves, try PV first.
- Harmless under Xen: `kvm_amd: SVM not supported` / kvm-intel load
  failures, `hctosys: unable to read the hardware clock`, `xen_mcelog:
  Failed to get CPU numbers`, `The kernel doesn't support reset from sysfs`
  for the xmg's xHCI.

## TODOs <!-- TODO: -->

- Is there any virtue in exposing nvim to the host? Remove the host-share and implement proper write back or remove exposing host to nvim.
- Remove not strictly needed host software
- think over dropping zsh on the host (zellij: gone from dom0 except on the hp, 2026-10-17)
- modularize config
- restructure vms/ vm folders should not live on the same level as modules/ etc.
- fix steam-vm bug: reboot is needed -> currently no way to do that. Maybe automate early reboot after first start and logging specific issue as trigger.
- improve steam-vm: initial wlserver: backend/hedless... is taking quiet long till steam starts (about 30s)
- let steam-vm participate in file sharing?
- Monitor occasionally occurring shared libs error in nvim-vm
- create sys-firewall
- screensharing: ideally only specific windows, at least for chat (per VM module)

## Misc

### Lazyvim

- workaround for oom errors
```bash
export MAKEFLAGS="-j1"
export CFLAGS="-O0"
export CXXFLAGS="-O0"
nvim --headless "+TSUninstall gitcommit" "+TSInstall gitcommit" +qa
```

### nix develop with a custom store

```sh
nix develop --store /mnt/user-store --extra-experimental-features nix-command --extra-experimental-features flakes
nix store gc --store /mnt/user-store --extra-experimental-features nix-command
```
