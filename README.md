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
- .7 wine
- .8 kali
- .9 office (no net, no autostart)
- .10 vault (no net, no autostart)
- .11 irc

## nvim-vm

- cp-vm nvim .ssh/id_ed25519
- cp-vm nvim .ssh/id_ed25519.pub
- gpg --list-secret-keys --keyid-format LONG
- gpg --export-secret-keys XXXXXXXXXX > privat.asc
- gpg --export XXXXXXXXXX > public.asc
- in vm: gpg --import privat.asc and gpg --import public.asc
- gh auth login
- cp-vm nvim .cache/oh-my-posh/themes/montys.omp.json
