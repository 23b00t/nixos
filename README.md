# NixOS, hyprland, microvm.nix

## Create Symlink

- mv /etc/nixos/ /etc/nixos.bak
- ln -s /home/nx/nixos-config /etc/nixos

## Build system

- sudo nixos-rebuild switch --flake ".#hp"

## VMs

### Create VMs

- Add entry to vms/registry.nix, e.g.:
  ```nix
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
  ```
- Add entry to flake.nix, e.g.:
  ```nix
  nvim.url = "path:./vms/nvim";
  ```
- Add a flake to vms/{name}/flake.nix which defines the microvm
  - Create a ssh key for the VM
- Import modules as needed, the usage of nearly all available modules is shown in vms/nvim/flake.nix

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

### Notification forwarding

- https://nikhilism.com/post/2023/remote-dbus-notifications/
- Implemented in common-config.nix and registry.nix (changed ssh.nix logic for it to make it possible to have the same key twice)

## libvirt

- virsh list --all --name
- virsh dumpxml mein-vm-name > /pfad/zu/deinem/backup/mein-vm-name.xml
- RESTORE: sudo rsync -avh --progress --sparse /run/media/nx/Backup/nixos-host/tails-amd64-6.15.1.img /run/media/nx/Backup/nixos-host/Whonix-Gateway.qcow2 /var/lib/libvirt/images/
- RESTORE: sudo virsh define /pfad/zu/deinem/backup/mein-vm-name.xml

## screensharing

<!-- TODO: Build sth. working - idealy with only sharing specific windows, would be fine if only chat-vm is the target (but should be addable by module) -->
vm: mpv http://192.168.178.20:8082/stream
host: wl-screenrec --output eDP-1 | ffmpeg -re -i - -f mpegts -codec:v mpeg1video -b:v 3000k -bf 0 http://0.0.0.0:8082/stream

## No WiFi

- sudo modprobe iwlwifi
```sh
nmcli radio all
```
```sh
nmcli radio wifi on
```

## TODOs <!-- TODO: -->

- cp-vm should read multiple files, not only one and folders
- backup and restore should be better tested and have a better output over success and failure
  - vms started by the scripts should be stoped after backup and restore
- Setup microvm binary
  - Solve manual vm adding to flake.nix -> registry should be improved and with sed we'll manipulate the main flake before nix evaluation
- Improve printing service (remove pre-condition of SSH Connection to the host)
- General refactoring and cleanup
- Remove unused host/ not strictly needed host software
- Modularize common-config.nix, net-config.nix, default-packages.nix etc.
- Debug and fix occasionally occurring shared libs error in nvim-vm
- cp-vm bug fix: script has to use the right key and not brute-force
- Improve ssh key sharing
- Fix element-desktop tray issue
- Fix bug that occasionally occurs at boot: Bootscreen isn't displayed and tty seems frozen till password is typed in blindly and boot finished successfully
- Fix: inter-vm copy-paste. Currently I can only copy in vm a to past than to host, to than copy from host to vm b.

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
