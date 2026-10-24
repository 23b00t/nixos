# office: documents, images, media; free software only (store group desktop).
# Printing: `vm-print <printer-ip> <file>` sends the document to sys-print
# (C2, NoX vms/sys-print); no CUPS and no network here.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    dconf
  ];
}
