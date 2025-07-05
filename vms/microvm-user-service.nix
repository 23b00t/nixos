{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.microvm-user;
in {
  options.services.microvm-user = {
    enable = mkEnableOption "MicroVM user service";
    
    vmPath = mkOption {
      type = types.str;
      description = "Path to the MicroVM directory";
      example = "/home/nx/nixos-config/vms/net";
    };
    
    user = mkOption {
      type = types.str;
      default = "nx";
      description = "User to run the MicroVM service";
    };
    
    vmName = mkOption {
      type = types.str;
      default = "net";
      description = "Name of the MicroVM";
    };
  };

  config = mkIf cfg.enable {
    # Install needed packages
    environment.systemPackages = with pkgs; [
      # Ensure microvm tools are available
      microvm
    ];

    # Add user to necessary groups
    users.users.${cfg.user}.extraGroups = [ "kvm" ];

    # Create the systemd user services
    systemd.user.services."microvm-${cfg.vmName}" = {
      description = "NixOS MicroVM (${cfg.vmName})";
      path = [ pkgs.microvm ];
      
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = cfg.vmPath;
        ExecStart = "${pkgs.microvm}/bin/microvm run";
        Restart = "no";
      };
    };

    # Create a script to run the VM interactively
    environment.systemPackages = with pkgs; [
      (writeScriptBin "run-microvm-${cfg.vmName}" ''
        #!${pkgs.bash}/bin/bash
        cd ${cfg.vmPath}
        
        if [ "$1" = "--interactive" ] || [ "$1" = "-i" ]; then
          ${pkgs.microvm}/bin/microvm run
        else
          systemctl --user start microvm-${cfg.vmName}
          echo "MicroVM ${cfg.vmName} started in background."
          echo "Use 'systemctl --user status microvm-${cfg.vmName}' to check status."
          echo "Use 'systemctl --user stop microvm-${cfg.vmName}' to stop the VM."
        fi
      '')
    ];
  };
}
