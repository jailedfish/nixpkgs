{ config, lib, pkgs, ... }:

let
  cfg = config.services.happd;
in
{
  options.services.happd = {
    enable = lib.mkEnableOption "Happ daemon";
  };

  config = lib.mkIf cfg.enable {
    systemd.packages = [ happ ];
    systemd.services.happd = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "/run/current-system/sw/bin/happd";
        
        User = "root";
        Group = "root";
        NoNewPrivileges = false;

        Restart = "on-failure";
        RestartSec = 5;

        TimeoutStopSec = 10;
        KillMode = "mixed";
        KillSignal = "SIGTERM";
      };
    };
  };
}
