# The user's part of every machine: user account, locale, own keyboards,
# laptop hardware profile, shell and tools (dom0-user.nix). Everything else of dom0
# comes from NoX (nixosModules.dom0-base, xen-dom0).
{
  inputs,
  ...
}:
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

  # User
  users.users = {
    nx = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
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
