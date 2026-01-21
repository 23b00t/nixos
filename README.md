# NixOS, Hyde.nix, microvm.nix

## Create Symlink

- mv /etc/nixos/ /etc/nixos.bak
- ln -s /home/nx/nixos-config /etc/nixos

## VMs

- .1 nvim
- .2 chat
- .3
- .4 music
- .5 net
- .6 net-private (no autostart)
- .7 wine (no autostart)
- .8 kali (no autstart)
- .9 office (no net, no autostart)
- .10 vault (no net, no autostart)
- .11 irc
- .12 steam
- .13 godot

- .254 host

### Create VMs

- vms/vm-name/flake.nix
- add in main flake.nix, configuration.nix, ssh.nix, copy-between-vms.nix, vm-connect.nix

## nvim-vm

- cp-vm nvim .ssh/id_ed25519
- cp-vm nvim .ssh/id_ed25519.pub
- gpg --list-secret-keys --keyid-format LONG
- gpg --export-secret-keys XXXXXXXXXX > privat.asc
- gpg --export XXXXXXXXXX > public.asc
- in vm: gpg --import privat.asc and gpg --import public.asc
- gh auth login
- cp-vm nvim .cache/oh-my-posh/themes/montys.omp.json

## libvirt

- virsh list --all --name
- virsh dumpxml mein-vm-name > /pfad/zu/deinem/backup/mein-vm-name.xml
- RESTORE: sudo rsync -avh --progress --sparse /run/media/nx/Backup/nixos-host/tails-amd64-6.15.1.img /run/media/nx/Backup/nixos-host/Whonix-Gateway.qcow2 /var/lib/libvirt/images/
- RESTORE: sudo virsh define /pfad/zu/deinem/backup/mein-vm-name.xml

## screensharing

vm: mpv http://192.168.178.20:8082/stream
host: wl-screenrec --output eDP-1 | ffmpeg -re -i - -f mpegts -codec:v mpeg1video -b:v 3000k -bf 0 http://0.0.0.0:8082/stream

## Wuthering Waves

- https://steamcommunity.com/app/3513350/discussions/0/506216918922078642/
- Properties -> launch options: SteamOS=1 %command% 

## Probleme

Dez 27 18:27:44 chat-vm nsncd[801]: Dec 27 17:27:44.153 ERRO error handling request, err: ESTALE: Stale file handle, request_type: GETPWBYNAME, thread: worker_2
Dez 27 18:27:44 chat-vm sshd[1168]: Privilege separation user sshd does not exist
Dez 27 18:28:06 chat-vm nsncd[801]: Dec 27 17:28:06.607 ERRO error handling request, err: ESTALE: Stale file handle, request_type: GETPWBYNAME, thread: worker_0
Dez 27 18:28:06 chat-vm sshd[1169]: Privilege separation user sshd does not exist

## No WiFi

- sudo modprobe iwlwifi

## steam vm 

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


### WuWa

PROTON_ENABLE_NVAPI=1
gamescope --steam --mangoapp --framerate-limit 60 
mangoapp ist problematisch

## Resize VM images 

 ● Um ein .img-Image um 30GB zu vergrößern
     sudo truncate -s +30G dateiname.img

 ● Nach dem Vergrößern des .img-Files das Dateisystem innerhalb der VM ebenfalls vergrößern, z.B. mit resize2fs für ext4. Starte die VM, öffne ein Terminal und führe dort (als root) resize2fs /dev/vdX aus, wobei /dev/vdX das gemountete Image ist.

## windowrule bug fix

 ~#@❯ rm windowrules.conf
 ~#@❯ ln -s /home/nx/nixos-config/home/windowrules.conf /home/nx/.local/share/hypr/windowrules.conf
 ~#@❯ rm windowrules.conf
 ~#@❯ ln -s /home/nx/nixos-config/home/windowrules.conf /home/nx/.config/hypr/windowrules.conf

## Misc

- Check value of option: e.g. sudo nixos-option home-manager.users.nx.xdg.enable

## nix develope

nix develop --store /mnt/user-store --extra-experimental-features nix-command --extra-experimental-features flakes
nix store gc --store /mnt/user-store --extra-experimental-features nix-command
