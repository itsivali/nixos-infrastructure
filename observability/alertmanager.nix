##############################################################################
#
# Alertmanager
#
# Purpose
# -------
# Configure Alertmanager with email notification routing.
#
# Ownership
# ---------
# services.prometheus.alertmanager
#
# Responsibilities
# ----------------
# - Route alerts via email
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
    enable = lib.mkEnableOption "Alertmanager with email routing";

    smtpSmarthost = lib.mkOption {
      type = lib.types.str;
      default = "smtp.office365.com:587";
      description = "SMTP server address for sending alerts";
    };

    smtpFrom = lib.mkOption {
      type = lib.types.str;
      default = "gitops@codlet-trench.ts.net";
      description = "Sender email address for alerts";
    };

    smtpAuthUsername = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "SMTP authentication username";
    };

    smtpAuthPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SOPS-encrypted file containing SMTP password";
    };

    emailTo = lib.mkOption {
      type = lib.types.str;
      default = "itsivali@outlook.com";
      description = "Recipient email address for alerts";
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

  config = lib.mkIf (cfg.enable && cfg.alertmanager.enable) (
    let
      alertCfg = cfg.alertmanager;
      hasSmtpAuth = alertCfg.smtpAuthPasswordFile != null;
    in
    {
      services.prometheus.alertmanager = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = alertmanagerPort;

        configuration = {
          global = {
            resolve_timeout = "5m";
            smtp_smarthost = alertCfg.smtpSmarthost;
            smtp_from = alertCfg.smtpFrom;
            smtp_require_tls = true;
          } // lib.optionalAttrs hasSmtpAuth {
            smtp_auth_username = alertCfg.smtpAuthUsername;
            smtp_auth_password_file = alertCfg.smtpAuthPasswordFile;
          };

          route = {
            receiver = "email";
            group_by = [ "alertname" "host" ];
            group_wait = alertCfg.groupWait;
            group_interval = alertCfg.groupInterval;
            repeat_interval = alertCfg.repeatInterval;

            routes = [
              {
                match = {
                  severity = "critical";
                };
                receiver = "email-critical";
                group_wait = "10s";
              }
              {
                match = {
                  severity = "warning";
                };
                receiver = "email";
              }
            ];
          };

          receivers = [
            {
              name = "email";
              email_configs = [
                {
                  to = alertCfg.emailTo;
                  send_resolved = true;
                }
              ];
            }
            {
              name = "email-critical";
              email_configs = [
                {
                  to = alertCfg.emailTo;
                  send_resolved = true;
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

      systemd.services.alertmanager = {
        serviceConfig = {
          MemoryMax = "16M";
          MemoryHigh = "12M";
          CPUQuota = "0.5%";
          CPUWeight = 20;
        };
      };
    }
  );
}
