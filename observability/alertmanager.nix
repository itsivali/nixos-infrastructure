##############################################################################
#
# Alertmanager
#
# Purpose
# -------
# Configure Alertmanager with Telegram notification routing.
#
# Ownership
# ---------
# services.prometheus.alertmanager
#
# Responsibilities
# ----------------
# - Route alerts to Telegram bot
# - Alert grouping and deduplication
# - Silence and inhibition rules
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;
  alertmanagerPort = 9093;
in
{
  options.ivali.observability.alertmanager = {
    enable = lib.mkEnableOption "Alertmanager with Telegram routing";

    telegramBotTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SOPS-encrypted file containing Telegram bot token";
    };

    telegramChatId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Telegram chat ID for alert notifications";
    };

    groupWait = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = "Wait time before sending initial alert";
    };

    groupInterval = lib.mkOption {
      type = lib.types.str;
      default = "5m";
      description = "Interval between alert group notifications";
    };

    repeatInterval = lib.mkOption {
      type = lib.types.str;
      default = "4h";
      description = "Interval for repeating unresolved alerts";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.alertmanager.enable) {
    services.prometheus.alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = alertmanagerPort;

      configuration = {
        global = {
          resolve_timeout = "5m";
        };

        route = {
          receiver = "telegram";
          group_by = [ "alertname" "host" ];
          group_wait = cfg.alertmanager.groupWait;
          group_interval = cfg.alertmanager.groupInterval;
          repeat_interval = cfg.alertmanager.repeatInterval;

          routes = [
            {
              match = {
                severity = "critical";
              };
              receiver = "telegram-critical";
              group_wait = "10s";
            }
            {
              match = {
                severity = "warning";
              };
              receiver = "telegram";
            }
          ];
        };

        receivers = [
          {
            name = "telegram";
            telegram_configs = [
              {
                bot_token = "{{ .Env.TELEGRAM_BOT_TOKEN }}";
                chat_id = cfg.alertmanager.telegramChatId;
                parse_mode = "HTML";
                message = ''
                  {{ range .Alerts }}
                  <b>{{ .Labels.alertname }}</b>
                  Host: {{ .Labels.host }}
                  Severity: {{ .Labels.severity }}
                  {{ .Annotations.description }}
                  {{ end }}
                '';
              }
            ];
          }
          {
            name = "telegram-critical";
            telegram_configs = [
              {
                bot_token = "{{ .Env.TELEGRAM_BOT_TOKEN }}";
                chat_id = cfg.alertmanager.telegramChatId;
                parse_mode = "HTML";
                message = ''
                  🚨 <b>CRITICAL ALERT</b>
                  {{ range .Alerts }}
                  <b>{{ .Labels.alertname }}</b>
                  Host: {{ .Labels.host }}
                  {{ .Annotations.description }}
                  {{ end }}
                '';
              }
            ];
          }
        ];

        inhibit_rules = [
          {
            source_match = {
              severity = "critical";
            };
            target_match = {
              severity = "warning";
            };
            equal = [ "alertname" "host" ];
          }
        ];
      };
    };

    # Provide bot token via environment file
    systemd.services.alertmanager = {
      serviceConfig = {
        EnvironmentFile = lib.mkIf (cfg.alertmanager.telegramBotTokenFile != null)
          cfg.alertmanager.telegramBotTokenFile;
      };
    };
  };
}
