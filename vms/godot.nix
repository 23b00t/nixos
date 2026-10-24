# godot: the Godot editor in two modes, switched by `gpu` in vms.nix and a
# rebuild:
# (a) gpu = true: Xen HVM with the NVIDIA dGPU passed through, its own
#     desktop (niri, foot) on the dGPU's output, input over USB/IP from
#     sys-usb (`vm-usb attach <device> godot`); the NVIDIA part is a copy of
#     steam.nix's
# (b) gpu = false: a VM like coding, windows over wprs; Godot renders in
#     software (Mesa llvmpipe), so the editor starts with the Compatibility
#     renderer (the `godot` app in vms.nix)
# (c) GPU for compute with a remote display: enhancement, late phase.
# Not enabled yet (enable = false in vms.nix).
{
  lib,
  pkgs,
  config,
  noxVm,
  ...
}:
let
  gpu = noxVm.gpu == true;
  # One zero byte: SeaBIOS reads fw_cfg integers as raw little-endian bytes
  optionRomExecOff = pkgs.runCommand "pci-optionrom-exec-0" { } "printf '\\000' > $out";
in
{
  config = lib.mkMerge [
    {
      microvm = {
        registerClosure = false;
        shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];
      };

      services = {
        common-config.browser = "firefox.desktop";
        zellij-env.tabsKdlFile = builtins.path {
          name = "tabs.kdl";
          path = ./godot/tabs.kdl;
        };
      };

      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          icu
          stdenv.cc.cc
          zlib
          icu
          expat
          openssl
          curl
          pulseaudio
          alsa-lib
          dbus
          mesa
          libglvnd
          vulkan-loader
          vulkan-headers
          libvorbis
          libogg
          libopus
          libpng
          libjpeg
          fontconfig
          freetype
          libuuid
          libxcb
          libx11
          libxext
          libxrandr
          libxcursor
          libxi
          libxtst
          libxinerama
          libxscrnsaver
          glib
          gtk3
        ];
      };

      environment.systemPackages = with pkgs; [
        xdg-utils
        godot
        wl-clipboard
        firefox
      ];
    }

    # (a) own desktop on the passed-through dGPU
    (lib.mkIf gpu {
      # Unfree, own store image
      nox.unfree = [
        "nvidia-x11"
        "nvidia-settings"
      ];

      microvm.xen = {
        # PCI passthrough with a PVH dom0 only works for HVM guests
        type = "hvm";
        # As steam: the NVIDIA driver writes config space registers pciback
        # filters otherwise; SeaBIOS must not run the card's VGA option ROM
        # (it hung there, steam 2026-10-14), the driver sets the card up itself
        extraConfig = ''
          pci_permissive = 1
          device_model_args_hvm = [ "-fw_cfg", "name=etc/pci-optionrom-exec,file=${optionRomExecOff}" ]
        '';
      };

      services = {
        xserver.videoDrivers = [ "nvidia" ];
        getty.autologinUser = "user";
        greetd = {
          enable = true;
          settings = rec {
            initial_session = {
              command = "niri-session";
              user = "user";
            };
            default_session = initial_session;
          };
        };
        pulseaudio.enable = false;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };
      };

      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
          grub.enable = lib.mkForce false;
        };
        kernelParams = [
          "vfio-pci.disable_idle_d3=1"
          "nvidia-drm.modeset=1"
          "pci=realloc=on"
          "pci=assign-busses"
        ];
        extraModprobeConfig = ''
          options vfio-pci disable_idle_d3=1
          options nvidia-drm modeset=1 fbdev=1
        '';
        blacklistedKernelModules = [ "nouveau" ];
        kernelPackages = pkgs.linuxPackages_zen;
      };

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };
        nvidia = {
          modesetting.enable = true;
          open = true;

          package = config.boot.kernelPackages.nvidiaPackages.stable;
          prime.offload.enable = false;
          prime.sync.enable = false;
          nvidiaSettings = true;
          powerManagement.enable = false;
          powerManagement.finegrained = false;
        };
      };

      programs.niri.enable = true;

      environment.etc = {
        # niri reads /etc/niri/config.kdl when ~/.config/niri has none
        "niri/config.kdl".source = ./godot/niri.kdl;
        # NVIDIA keeps freed VRAM for reuse in Wayland compositors (~1 GiB
        # for niri instead of ~100 MiB): niri's documented workaround
        "nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
          builtins.toJSON {
            rules = [
              {
                pattern = {
                  feature = "procname";
                  matches = "niri";
                };
                profile = "Limit Free Buffer Pool On Wayland Compositors";
              }
            ];
            profiles = [
              {
                name = "Limit Free Buffer Pool On Wayland Compositors";
                settings = [
                  {
                    key = "GLVidHeapReuseRatio";
                    value = 0;
                  }
                ];
              }
            ];
          };
      };

      security.rtkit.enable = true;
    })
  ];
}
