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
      # Fix: Microsoft 365 (smtp.office365.com) rejects a From address that is
      # not the authenticated mailbox. The default previously used the Tailnet
      # pseudo-domain (gitops@codlet-trench.ts.net), which Office365 rejects,
      # so no alert emails were ever delivered. The authenticated Outlook
      # mailbox (itsivali@outlook.com) is the only usable sender.
      default = "itsivali@outlook.com";
      description = "Sender email address for alerts (must match the authenticated Office365 mailbox)";
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
          # Fix: 16M/12M was too low. At that limit alertmanager sat at ~12M
          # RSS with <100KB free in its cgroup and its HTTP listener stopped
          # accepting connections (curl to 127.0.0.1:9093 → connection
          # refused) even though the unit reported active. Bumped to 160M/128M
          # so it can buffer alert backlog and serve /-/ready + the API.
          MemoryMax = "160M";
          MemoryHigh = "128M";
          CPUQuota = "0.5%";
          CPUWeight = 20;
        };
      };
    }
  );
}
