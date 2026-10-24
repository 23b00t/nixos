# vanilla: only what common-config brings, no packages of its own in the repo.
# Software comes in imperatively (`nix profile install nixpkgs#…`) and stays
# in the persistent store overlay across reboots; GUI apps over wprs.
{ inputs, ... }:
{
  imports = [ (inputs.nox.lib.vms + "/modules/persistent-store-overlay.nix") ];

  # Own closure valid in the Nix DB, so a GC in the overlay never deletes it
  # (as in coding/builder)
  microvm.registerClosure = true;

  services.persistentStoreOverlay.enable = true;
}
