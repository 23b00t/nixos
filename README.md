# NixOS, hyprland, microvm.nix

## Create Symlink

- mv /etc/nixos/ /etc/nixos.bak
- ln -s /home/nx/nixos-config /etc/nixos

## Build system

- sudo nixos-rebuild switch --flake ".#hp"

## Xen test phase (hp, v1)

The migration plan (v2+) is in [xen-migration.md](xen-migration.md).

The hp branch turns the HP laptop into a Xen dom0 (`machines/hp/xen.nix`) and runs MicroVMs as Xen PVH domUs via the microvm.nix fork (`github:23b00t/microvm.nix/xen`, input `microvm` in `flake.nix`).

Scope of v1: `microvm.hypervisor = "xen"` is the only change in a VM definition (`vault`, `nvim`, `coding`). `/nix/store` comes from an erofs store disk; other shares are dropped with a warning (nvim has no `/mnt/host`). No PCI/USB passthrough, ballooning or 9pfs yet (v2). There is no sys-net, so VMs only reach the host (`10.0.0.254`), not the internet.

Test-phase extras in `machines/hp/dev-access.nix`: `claude-code`, `google-chrome`, key-only SSH for `nx` from `192.168.178.0/24` (no root login), and passwordless sudo for `xl`, `nixos-rebuild switch` and `systemctl start|stop|restart|kill microvm@*` so Claude can run the test plan.

### Build and boot

```bash
git pull
nix flake update microvm                 # lock the fork's xen branch
nix build .#nixosConfigurations.hp.config.system.build.toplevel --dry-run
sudo nixos-rebuild boot --flake .#hp
```

Reboot and pick the `xen-…` boot entry. The plain NixOS entries stay as fallback.

dom0 has 8192 MB. Evaluating the hp configuration peaks at ~6.6 GB; with 4096 MB it thrashes swap for many minutes. If dom0 is short on memory for a rebuild, balloon it up live: `sudo xl mem-set 0 12g`. Don't add specialisations to hp: each one evaluates the host and all MicroVMs again and no longer fits.

Changes in `machines/hp/xen.nix` that remove a running service (e.g. `xendomains`) should be applied with `nixos-rebuild boot` + reboot: stopping `xendomains` runs `xl shutdown --all` and takes all VMs down.

### Test system

| | |
|---|---|
| Model | HP Laptop 15s-eq2xxx (board 887A, BIOS F.32 2023-10-03) |
| CPU / GPU | AMD Ryzen 5 5500U (Zen 2, 6C/12T), Radeon "Lucienne" iGPU `1002:164c` (amdgpu) |
| RAM | 32 GB (dom0 8192 MB, 4 vCPUs) |
| WiFi | Realtek RTL8821CE `10ec:c821` (rtw88, NetworkManager in dom0) |
| Touchpad | ELAN071A (`04f3:30fd`), I2C-HID on `AMDI0010:03` (`\_SB_.I2CD.TPD0`), interrupt via the AMD GPIO controller `AMDI0030` (`\_SB_.GPIO`) |
| Software | Xen 4.22.0, Linux 7.2.9-zen1, NixOS 26.11 (Lix) |

### Known hardware issues

- **Touchpad dead under PVH dom0.** The AMD GPIO controller gets no interrupt: `amd_gpio AMDI0030:00: error -EINVAL: IRQ index 0 not found`, so `i2c_hid_acpi` cannot bind ELAN071A. With a **PV dom0** (`dom0=pv`) the same kernel probes `amd_gpio` (only a harmless "failed to enable wake-up interrupt") and the touchpad shows up as input device. Tested 2026-10-05. Likely cause (not verified): the PVH dom0 kernel runs with a NULL legacy PIC and cannot register the level/low legacy GSI of the GPIO controller; a PV dom0 registers GSIs through Xen instead. The old `xen` branch (Intel machine) showed the same pattern ("pvh without touchpad").
- **Rule of thumb:** PVH dom0 stays the target (also for the XMG). If dom0 hardware misbehaves (missing interrupts, dead input devices), try a PV dom0 first: change `"dom0=pvh"` to `"dom0=pv"` in `virtualisation.xen.boot.params` and rebuild with `boot`. Requires `CONFIG_XEN_PV=y` and `CONFIG_XEN_DOM0=y` (set in the zen kernel).
- Harmless log noise under Xen: `kvm_amd: SVM not supported` (hardware-configuration loads `kvm-amd`), ACPI `VRTC`/`hctosys: unable to read the hardware clock` (Xen owns the RTC, `timedatectl` cannot read it), `ccp … tee: ring init command failed`, `xen_mcelog: Failed to get CPU numbers`.

### Test plan

1. dom0 is up: `sudo xl info` (Xen version, dom0 memory 8192 MB), `sudo xl list` shows `Domain-0`, niri desktop works, `systemctl status xenstored xenconsoled`.
2. Autostart: `systemctl status microvm@vault microvm@nvim microvm@coding` are active; `sudo xl list` shows `vault-vm`, `nvim-vm`, `coding-vm` with the configured memory/vCPUs.
3. Guest boot: `sudo xl console vault-vm` (leave with `Ctrl+]`) or the logs in `/var/log/xen/console/`; no emergency shell, `/nix/store` and `/home/user` mounted.
4. Network: `ip link show master vm-internal` lists `vm10`, `vm1`, `vm6`; `ssh 10.0.0.10` / `ssh 10.0.0.1` / `ssh 10.0.0.6` (or `vm-run -c <vm> …`) work from the host (host keys `~/.ssh/<vm>-vm` must exist on the hp). The `<vm>-vm` names don't resolve (no DNS/hosts entry), only the IPs.
5. Persistence: create a file in `/home/user` of a VM, `sudo systemctl restart microvm@vault`, the file is still there.
6. Lifecycle: `sudo systemctl stop microvm@vault` shuts the domain down cleanly (gone from `xl list` within 60 s, journal shows no `xl destroy`); `start` brings it back; `vm-run -c`/`vm` helpers work for the three VMs.
7. Guest reboot/crash: `sudo reboot` inside a VM → the service restarts it (new domain id in `xl list`).
8. Stale domain: `sudo kill -9 <xl pid of microvm@vault>` → the service restarts and destroys the leftover domain first.
9. Host shutdown: reboot dom0; the guests shut down cleanly (no fsck/journal recovery messages on next boot).
10. SSH: from a LAN machine `ssh nx@<hp-ip>` works with the `hp` key; root login is refused; from a VM on `10.0.0.0/24` port 22 is not reachable.
11. Desktop: niri runs in dom0; a GUI app from a VM shows up via wprs (`vm-run cc firefox`).

Collect for failures: `journalctl -b -u microvm@<vm>`, `/var/log/xen/console/guest-<vm>-vm.log`, `/var/log/xen/xl-<vm>-vm.log`, `/var/log/xen/xen-hotplug.log`, `sudo xl dmesg | tail -50`.

### Results (2026-10-05)

All 11 tests passed, with these notes:

- 6: needed the fork fix "wait for domain cleanup on shutdown"; before it, every stop left a shut-down domain behind that the next start destroyed.
- 9: guests shut down in 1–5 s and boot without ext4 recovery. dom0 shutdown hung 90 s in `xendomains` (it runs `xl shutdown --all --wait` in parallel to the `microvm@` services); `xendomains` is now disabled in `machines/hp/xen.nix` (configured, verify on the next reboot).
- 11: touchpad only with PV dom0, see "Known hardware issues".
- Expected on hp: `ide-lazyvim-config` fails in coding (no internet without sys-net); niri's `spawn-at-startup` `vm-run` calls try to start VMs that don't exist on hp (polkit failures in the journal); `vm-dbus-forward@<vm>` units for those VMs restart in a loop.

## VMs

### Create VMs

- Add entry to `vms/registry.nix`, e.g.:
  ````nix
  {
    name = "nvim";
    short = "n";
    ip = "10.0.0.1";
    autostart = true;
    nat = true;
    sshKeyName = "nvim-vm";
    extraSSH = {
      RemoteForward = "4713 localhost:4713";
    };
  }
  ````
- Add a local VM definition to `vms/definitions.nix`
- Create the VM module at `vms/{name}/default.nix`
  - Create a host ssh key for the VM: `ssh-keygen -C my-vm`
- If the VM should participate in file sharing between VMs, use on the host: `vmcopy-keys <new-vm-name>` and rebuild again
- Import modules as needed; examples now live in the VM `default.nix` files such as `vms/nvim/default.nix`

### Additional setup for ide vms

- cp-vm {name} privat.asc public.asc
- in vm: gpg --import privat.asc and gpg --import public.asc
```bash
  chmod 700 ~/.gnupg
  chmod 600 ~/.gnupg/*
  gpg --list-keys
  gpg --edit-key <KEY-ID>
  # dann im GPG-Prompt:
  # trust
  # 5
  # y
  # quit
```
- gh auth login

### Resize VM images 

- To increase the size of a .img image file by 30GB:
```bash
sudo truncate -s +30G filename.img
```

- After enlarging the .img file resize it in the vm:
```bash
lsblk
sudo resize2fs /dev/vdX
```

### Temporarily allow VM to Host SSH Connection (for copy to host)

- sudo iptables -I INPUT 1 -p tcp --dport 22 -s 10.0.0.1 -j ACCEPT
- And directly remove it again:
  - sudo iptables -D INPUT -p tcp --dport 22 -s 10.0.0.1 -j ACCEPT

### Notification and tray forwarding

- https://nikhilism.com/post/2023/remote-dbus-notifications/
- Implemented in common-config.nix and registry.nix (changed ssh.nix logic for it to make it possible to have the same key twice)
- Configured dbus-proxy

## Network architecture and documentation

### Current model

The system now follows a more Qubes-like split:

- the host is mainly responsible for:
  - hypervisor duties
  - local L2 plumbing
  - running MicroVMs and libvirt
- `sys-net` is the main external network boundary
- regular MicroVMs use the internal host bridge and route through `sys-net`
- libvirt guest trust zones are bridged on the host, but L3/NAT/DHCP policy for migrated external zones lives in `sys-net`

### Important bridges and roles

- `vm-internal`
  - host internal bridge for MicroVMs
  - host address: `10.0.0.254/24`
  - `sys-net` router address: `10.0.0.253/24`
- `virbr0`
  - bridge-backed libvirt network for `default`
  - guest-facing gateway is provided by `sys-net` on `192.168.122.1`
- `virbr1`
  - bridge-backed libvirt network for `Whonix-External`
  - guest-facing gateway is provided by `sys-net` on `10.0.2.2`
- `virbr2`
  - `Whonix-Internal`
  - currently kept as a separate protected trust domain

### Important implementation detail

Host `systemd-networkd` must not manage libvirt `vnet*` interfaces.

The fix is in `machines/common-configuration.nix`:

```nix
"38-vnet-libvirt-ignore" = {
  matchConfig.Name = "vnet*";
  linkConfig.Unmanaged = "yes";
};
```

Without this, host `systemd-networkd` reconfigures libvirt tap devices and breaks their bridge forwarding state.

### Host internet policy

The host still uses `sys-net` as its default gateway via `vm-internal`, but host egress is now intended to stay minimal.

Current design goal:

- host may reach VMs for management
- VMs should not reach the host by default
- host internet should ideally be restricted to maintenance traffic such as:
  - SSH
  - HTTP/HTTPS
  - DNS
  - NTP
  - ICMP for diagnostics

This restriction is enforced in `vms/sys-net/default.nix` on traffic coming from host address `10.0.0.254` via `vm-lan`.

### Printing migration

Printing and mDNS/Avahi service ownership were moved off the host and into `sys-net`.

- `sys-net` now runs CUPS and Avahi
- the `office` VM tunnels to `sys-net` instead of to the host
- in the `office` VM, `/root/.ssh/print-gateway` is the private key used to SSH to `sys-net`
- the matching public key must be authorized on `sys-net`

Note: this printer migration is configured, but end-to-end runtime testing is still pending.

## libvirt

- virsh list --all --name
- virsh dumpxml mein-vm-name > /pfad/zu/deinem/backup/mein-vm-name.xml
- RESTORE: sudo rsync -avh --progress --sparse /run/media/nx/Backup/nixos-host/tails-amd64-6.15.1.img /run/media/nx/Backup/nixos-host/Whonix-Gateway.qcow2 /var/lib/libvirt/images/
- RESTORE: sudo virsh define /pfad/zu/deinem/backup/mein-vm-name.xml

## screensharing

<!-- TODO: Build sth. working - idealy with only sharing specific windows, would be fine if only chat-vm is the target (but should be addable by module) -->
vm: mpv http://192.168.178.20:8082/stream
host: wl-screenrec --output eDP-1 | ffmpeg -re -i - -f mpegts -codec:v mpeg1video -b:v 3000k -bf 0 http://0.0.0.0:8082/stream
- Actually only sharing should be on per module basis per vm which participates in sharable. If that could be possible with wprs?

## No WiFi

- sudo modprobe iwlwifi
```sh
nmcli radio all
```
```sh
nmcli radio wifi on
```

## TODOs <!-- TODO: -->

- Test migrated printing path via `sys-net` end-to-end
- Is there any virtue in exposing nvim to the host? Remove the host-share and implement proper write back or remove exposing host to nvim.

- Remove not strictly needed host software
- think over dropping zellij and zsh on the host
- modularize config
- restructure vms/ vm folders should not live on the same level as modules/ vmcopy-keys/ etc.

- fix steam-vm bug: reboot is needed -> currently no way to do that. Maybe automate early reboot after first start and logging specific issue as trigger.
- improve steam-vm: initial wlserver: backend/hedless... is taking quiet long till steam starts (about 30s)
- let steam-vm participate in file sharing?

- think about removing fluxbox workflow. what's with wine vm? a libvirt vm could be an alternative. -> kind of have done that, but wine-vm is still experimental and probably needs hyprland. 

- Monitor occasionally occurring shared libs error in nvim-vm
- Monitor element-desktop tray issue

- Monitor bug that occasionally occurs at boot: Bootscreen isn't displayed and tty seems frozen till password is typed in blindly and boot finished successfully
  ```bash
  sudo dmesg -T | grep -iE "drm"
  [Mi Mai  6 19:02:30 2026] ACPI: bus type drm_connector registered
  [Mi Mai  6 19:02:30 2026] simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
  [Mi Mai  6 19:02:30 2026] [drm] Initialized simpledrm 1.0.0 for simple-framebuffer.0 on minor 0
  [Mi Mai  6 19:02:30 2026] simple-framebuffer simple-framebuffer.0: [drm] fb0: simpledrmdrmfb frame buffer device
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] Found alderlake_s/raptorlake_s (device ID a788) integrated display version 12.00 stepping D0
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] VT-d active for gfx access
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] Using Transparent Hugepages
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] Finished loading DMC firmware i915/adls_dmc_ver2_01.bin (v2.1)
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] GT0: GuC firmware i915/tgl_guc_70.bin version 70.49.4
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] GT0: HuC firmware i915/tgl_huc.bin version 7.9.3
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] GT0: HuC: authenticated for all workloads
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] GT0: GUC: submission enabled
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] GT0: GUC: SLPC enabled
  [Mi Mai  6 19:02:31 2026] i915 0000:00:02.0: [drm] GT0: GUC: RC enabled
  [Mi Mai  6 19:02:32 2026] i915 0000:00:02.0: [drm] Registered 4 planes with drm panic
  [Mi Mai  6 19:02:32 2026] [drm] Initialized i915 1.6.0 for 0000:00:02.0 on minor 1
  [Mi Mai  6 19:02:32 2026] fbcon: i915drmfb (fb0) is primary device
  [Mi Mai  6 19:02:32 2026] i915 0000:00:02.0: [drm] fb0: i915drmfb frame buffer device
  [Mi Mai  6 19:02:55 2026] systemd[1]: Load Kernel Module drm skipped, unmet condition check ConditionKernelModuleLoaded=!drm
  ```
  - Same on 14.05.2026

- create sys-firewall

## Misc

### steam vm 

lspci -nn | grep -E "VGA|3D|Audio"
nvidia-smi || true
ls -lah /dev/dri
sudo dmesg -T | grep -iE "nvidia|drm|nouveau" | tail -n 200
sudo cat /var/log/steam-autostart.log || true

 ~#@❯ sudo cp -f --reflink=auto ./result-steam-qcow2/steam-os.qcow2 /var/lib/libvirt/images/steam-os.qcow2
 ~#@❯ sudo sync
 ~#@❯ sudo stat -c '%n inode=%i size=%s mtime=%y' /var/lib/libvirt/images/steam-os.qcow2
/var/lib/libvirt/images/steam-os.qcow2 inode=32506532 size=9143189504 mtime=2026-01-07 15:40:27.739643137 +0100


1. **Geräte vor VM-Start freigeben:**  
   Sorge dafür, dass die USB- und PCI-Geräte vor dem VM-Start nicht vom Host verwendet werden.  
   Prüfe mit:
   ```
   lsof /dev/bus/usb/*/*
   fuser /dev/bus/usb/*/*
   ```

2. **Automatisches Unbinden der Geräte:**  
   Füge ein Skript oder einen systemd-Service hinzu, der vor dem VM-Start die Geräte unbindet:
   ```
   echo '1-1' > /sys/bus/usb/drivers/usb/unbind
   ```
   (Passe die Busnummer an dein Gerät an.)

3. **VFIO-Binding sicherstellen:**  
   Stelle sicher, dass die PCI-Geräte vor dem VM-Start an VFIO gebunden sind:
   ```
   echo 0000:02:00.0 > /sys/bus/pci/devices/0000:02:00.0/driver/unbind
   echo 8086 1234 > /sys/bus/pci/drivers/vfio-pci/new_id
   echo 0000:02:00.0 > /sys/bus/pci/drivers/vfio-pci/bind
   ```
   (IDs und Pfade anpassen!)

4. **systemd-Unit für sauberes Binding:**  
   Erstelle eine systemd-Unit auf dem Host, die vor dem VM-Start die Geräte vorbereitet.

### windowrule bug fix

 ~#@❯ rm windowrules.conf
 ~#@❯ ln -s /home/nx/nixos-config/home/windowrules.conf /home/nx/.local/share/hypr/windowrules.conf
 ~#@❯ rm windowrules.conf
 ~#@❯ ln -s /home/nx/nixos-config/home/windowrules.conf /home/nx/.config/hypr/windowrules.conf

### Nixos

- Check value of option: e.g. sudo nixos-option home-manager.users.nx.xdg.enable
- nix build ".#nixosConfigurations.xmg.config.system.build.toplevel" --dry-run

### nix develope

nix develop --store /mnt/user-store --extra-experimental-features nix-command --extra-experimental-features flakes
nix store gc --store /mnt/user-store --extra-experimental-features nix-command

### devenv wrapper with custom nix store - didn't work as expected

```nix
"nix.conf".text = ''
  store = /mnt/user-store
  substituters = https://cache.nixos.org/
  trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
  sandbox = false 
  require-sigs = true
  auto-optimise-store = false 
  extra-experimental-features = nix-command flakes
'';
systemd.tmpfiles.rules = [
  # alternative user store
  "d /home/user/.config/nix 0755 user users -"
  "L+ /home/user/.config/nix/nix.conf - - - - /etc/nix.conf"
];
```

```bash
nix profile add 'nixpkgs#devenv'
mkdir -p ~/.local/bin
echo '#!/bin/sh
exec $(find /mnt/user-store/nix/store -type f -name devenv | sort | tail -1) "$@"
' > ~/.local/bin/devenv
chmod +x ~/.local/bin/devenv
```

### Export GPG keys 

- gpg --list-secret-keys --keyid-format LONG
- gpg --export-secret-keys XXXXXXXXXX > privat.asc
- gpg --export XXXXXXXXXX > public.asc

### Lazyvim

- workaround for oom errors
```bash
export MAKEFLAGS="-j1"
export CFLAGS="-O0"
export CXXFLAGS="-O0"
nvim --headless "+TSUninstall gitcommit" "+TSInstall gitcommit" +qa
```
