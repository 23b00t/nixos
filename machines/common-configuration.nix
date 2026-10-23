# The user's part of every machine: user account, locale, own keyboards,
# laptop hardware profile, shell and tools (dom0-user.nix). Everything else of dom0
# comes from NoX (nixosModules.dom0-base, xen-dom0).
{
  lib,
  config,
  pkgs,
  inputs,
  vmRegistry,
  ...
}:
let
  mkVmReservedUsbRule =
    device:
    let
      udev = device.udev or { };
      group = udev.group or "kvm";
      modePart = lib.optionalString (udev ? mode) '', MODE="${udev.mode}"'';
      udisksPart = lib.optionalString (udev.udisksIgnore or false
      ) '', ENV{UDISKS_IGNORE}="1", TAG-="uaccess"'';
    in
    ''SUBSYSTEM=="usb", ATTR{idVendor}=="${device.vendorId}", ATTR{idProduct}=="${device.productId}", GROUP="${group}"${modePart}${udisksPart}'';

  vmReservedUsbRules = lib.concatMapStringsSep "\n" mkVmReservedUsbRule (
    vmRegistry.hardware.usb.vmReserved or [ ]
  );
in
{
  imports = [
    # Hardware Configuration - Uncomment lines that match your hardware
    # Run `lshw -short` or `lspci` to identify your hardware

    # GPU Configuration (choose one):
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia

    # Additional Hardware Modules - Uncomment based on your system type:
    inputs.nixos-hardware.nixosModules.common-hidpi # High-DPI displays
    inputs.nixos-hardware.nixosModules.common-pc-laptop # Laptops
    inputs.nixos-hardware.nixosModules.common-pc-ssd # SSD storage

    ./dom0-user.nix
  ];

  services.udev = {
    extraRules = ''
      # Keyboard
      SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="2303", GROUP="kvm"
      # Mouse
      SUBSYSTEM=="usb", ATTR{idVendor}=="260d", ATTR{idProduct}=="1121", GROUP="kvm"
    ''
    + lib.optionalString (vmReservedUsbRules != "") ''

      # VM-reserved USB devices are generated from vms/registry.nix
      ${vmReservedUsbRules}
    '';
    packages = [
      (pkgs.writeTextFile {
        name = "kaleidoskope-udev-rules";
        destination = "/etc/udev/rules.d/50-kaleidoskope.rules";
        text = ''
          # Kaleidoscope keyboards
          SUBSYSTEMS=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="2303", SYMLINK+="Atreus",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
          SUBSYSTEMS=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="2302", SYMLINK+="Atreus",  ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0", TAG+="uaccess", TAG+="seat"
        '';
      })
    ];
  };

  # User
  users.users = {
    nx = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "kvm"
        "input"
      ];
    };
  };

  # networking.wireless.enable = true;

  # Time & Locals
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  # i18n.extraLocales = "de_DE.UTF-8/UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_ADDRESS = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    # https://www.reddit.com/r/NixOS/comments/11be3cy/i_need_some_help_changing_the_system_language/
  };

  nix.settings.trusted-users = [
    "nx"
  ];

  system.stateVersion = "26.05";
}
