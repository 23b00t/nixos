{ pkgs, ... }:
{
  imports = [
__MODULE_IMPORTS__
  ];

  networking.hostName = "__VM_NAME__-vm";

  services.net-config = {
    enable = true;
    index = __NET_INDEX__;
    mac = "__MAC_ADDR__";
  };

  services.common-config.enable = true;
__EXTRA_SERVICE_BLOCKS____PERSISTENT_SERVICE_LINE__
  microvm = {
    registerClosure = false;
    hypervisor = "cloud-hypervisor";
    volumes = [
      {
        mountPoint = "/home/user";
        image = "home.img";
        size = __HOME_IMG_SIZE__;
      }
    ];
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    mem = __MEM__;
    vcpu = __VCPUS__;
  };

  system.stateVersion = "26.05";
}
