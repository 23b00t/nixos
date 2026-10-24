# win: Windows apps (no gaming, games stay in steam). Small, unknown Win apps
# and, as far as Wine allows, MS Office/Outlook. Bottles with one prefix per
# app: wine-staging/soda as default runner, Proton-GE/umu as extra runners
# for problem cases (Bottles downloads them itself). No GPU (the dGPU belongs
# to steam): Mesa in software (llvmpipe/lavapipe, role windows). Internet
# yes, isolated from the other VMs, no session bus from dom0.
{ lib, pkgs, ... }:
{
  # Windows core fonts (Office documents render with the right metrics);
  # unfree, so win sits in the store group prop
  fonts.packages = lib.mkAfter (
    with pkgs;
    [
      corefonts
      vista-fonts
    ]
  );
  nox.unfree = [
    "corefonts"
    "vista-fonts"
    # pulled in by bottles (Lossless Scaling frame generation)
    "lsfg-vk"
  ];

  environment.systemPackages = with pkgs; [
    # apps.bottles.install = false: this build without the warning popup
    (bottles.override { removeWarningPopup = true; })
    # System Wine for winetricks outside Bottles
    wineWow64Packages.stagingFull
    winetricks
    umu-launcher
    cabextract
  ];

  # dom0's pulse over vchan (vms/modules/vchan-relay.nix)
  environment.variables = {
    PULSE_SERVER = "unix:/tmp/wprs-pulse";
  };
}
