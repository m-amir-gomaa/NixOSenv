{ config, pkgs, lib, ... }:

{
  options.services.titan-gateway = {
    enable = lib.mkEnableOption "Titan Gateway LiteLLM Proxy";
    configPath = lib.mkOption {
      type = lib.types.path;
      default = "/home/qwerty/TitanGateway/config.yaml";
      description = "Path to the LiteLLM config.yaml";
    };
    envFile = lib.mkOption {
      type = lib.types.path;
      default = "/home/qwerty/TitanGateway/.env";
      description = "Path to the .env file containing API keys";
    };
  };

  config = lib.mkIf config.services.titan-gateway.enable {
    # Add necessary packages for the agentic ecosystem
    environment.systemPackages = with pkgs; [
      litellm
    ];

    systemd.user.services.titan-proxy = {
      description = "Titan Gateway LiteLLM Proxy (Antigravity Failover)";
      wantedBy = [ "graphical-session.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.litellm}/bin/litellm --config ${config.services.titan-gateway.configPath} --port 4000";
        EnvironmentFile = config.services.titan-gateway.envFile;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
