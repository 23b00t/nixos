# win: Windows apps (no gaming, games stay in steam). Small, unknown Win apps
# and, as far as Wine allows, MS Office/Outlook. Bottles with one prefix per
# app: wine-staging/soda as default runner, Proton-GE/umu as extra runners
# for problem cases (Bottles downloads them itself). No GPU (the dGPU belongs
# to steam): Mesa in software (llvmpipe/lavapipe). Internet yes, isolated from
# the other VMs (uplink isolation in sys-net), no session bus from dom0.
# Plan: xen-migration.md "Phase 4: Neue VMs".
{ pkgs, inputs, ... }:
{
  imports = [
    (inputs.nox.lib.vms + "/modules/common-config.nix")
    (inputs.nox.lib.vms + "/modules/net-config.nix")
  ];

  networking.hostName = "win-vm";
  nixpkgs.config.allowUnfree = true;

  services.net-config = {
    enable = true;
    index = 7;
    mac = "00:00:00:00:00:07";
  };
  services.common-config = {
    enable = true;
  };

  microvm = {
    hypervisor = "xen";
    volumes = [
      {
        # Bottles keeps runners and prefixes in ~/.local/share/bottles
        mountPoint = "/home/user";
        image = "home.img";
        size = 40000;
      }
    ];
    # Boots with 2048 MB, the RAM balancer grows it up to 6144 MB
    mem = 6144;
    balloon = true;
    initialBalloonMem = 2048;
    vcpu = 4;
  };

  # Software rendering (OpenGL and Vulkan), 32-bit for 32-bit Windows apps
  # (Office 2016/2019 32-bit)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Windows core fonts (Office documents render with the right metrics)
  fonts.packages = with pkgs; [
    corefonts
    vista-fonts
  ];

  environment.systemPackages = with pkgs; [
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

  system.stateVersion = "26.05";
}
