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
    # Add user to necessary groups
    users.users.${cfg.user}.extraGroups = [ "kvm" ];

    # Create a script to run the VM interactively or start/stop the system service
    environment.systemPackages = with pkgs; [
      (writeScriptBin "run-microvm-${cfg.vmName}" ''
        #!${pkgs.bash}/bin/bash
        
        if [ "$1" = "--interactive" ] || [ "$1" = "-i" ]; then
          echo "Starte MicroVM ${cfg.vmName} im interaktiven Modus..."
          cd ${cfg.vmPath}
          sudo ${cfg.vmPath}/result/bin/virtiofsd-run &
          sleep 2
          sudo ${cfg.vmPath}/result/bin/microvm-run
        else
          sudo systemctl start microvm-${cfg.vmName}
          echo "MicroVM ${cfg.vmName} im Hintergrund gestartet."
          echo "Verwende 'sudo systemctl status microvm-${cfg.vmName}' um den Status zu prüfen."
          echo "Verwende 'sudo systemctl stop microvm-${cfg.vmName}' um die VM zu stoppen."
        fi
      '')
    ];

    # Create the systemd system service (runs as root)
    systemd.services."microvm-${cfg.vmName}" = {
      description = "NixOS MicroVM (${cfg.vmName})";
      
      # Don't start automatically
      wantedBy = [];
      
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = cfg.vmPath;
        ExecStart = "${cfg.vmPath}/result/bin/microvm-run";
        ExecStop = "${cfg.vmPath}/result/bin/microvm-shutdown";
        Restart = "no";
        
        # Add some security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [ cfg.vmPath ];
      };
    };
    
    # Allow the user to start and stop the VM service without password
    security.sudo.extraRules = [{
      users = [ cfg.user ];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemctl start microvm-${cfg.vmName}";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl stop microvm-${cfg.vmName}";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl status microvm-${cfg.vmName}";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${cfg.vmPath}/result/bin/microvm-run";
          options = [ "NOPASSWD" ];
        }
      ];
    }];
  };
}
