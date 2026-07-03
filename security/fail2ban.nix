##############################################################################
#
# Fail2Ban
#
# Purpose
# -------
# Brute-force protection for SSH, nginx, and the Telegram bot webhook.
#
# Ownership
# ---------
# services.fail2ban
#
# Does NOT Own
# ------------
# - Sudo (security/sudo.nix)
# - System hardening (security/hardening.nix)
# - AppArmor (security/apparmor.nix)
# - Packages (security/packages.nix)
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.security.fail2ban;
in
{
  options.ivali.security.fail2ban = {
    enable = lib.mkEnableOption "fail2ban with extended jails";

    nginx.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.services.nginx.enable;
      description = "Enable fail2ban jail for nginx";
    };

    bot.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.fleet.bot.enable or false;
      description = "Enable fail2ban jail for Telegram bot webhook";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fail2ban = {
      enable = true;

      bantime = "1h";

      ignoreIP = [
        "127.0.0.0/8"
        "::1"
      ];

      bantime-increment = {
        enable = true;
        overalljails = true;
        maxtime = "168h";
        multipliers = "2 4 8 16 32 64 128 256 512 1024";
      };

      # ── SSH jail (default) ────────────────────────────────────
      jails.sshd.settings = {
        enabled = true;

        filter = "sshd";
        backend = "%(sshd_backend)s";

        port = "ssh";
        logpath = "%(sshd_log)s";

        maxretry = 3;
        findtime = "10m";
        bantime = "1h";
      };

      # ── Nginx HTTP auth jail ──────────────────────────────────
      jails.nginx-http-auth.settings = lib.mkIf cfg.nginx.enable {
        enabled = true;

        filter = "nginx-http-auth";
        backend = "auto";

        port = "http,https";
        logpath = "/var/log/nginx/error.log";

        maxretry = 5;
        findtime = "10m";
        bantime = "1h";
      };

      # ── Nginx bad request jail ────────────────────────────────
      jails.nginx-bad-request.settings = lib.mkIf cfg.nginx.enable {
        enabled = true;

        filter = "nginx-bad-request";
        backend = "auto";

        port = "http,https";
        logpath = "/var/log/nginx/access.log";

        maxretry = 10;
        findtime = "10m";
        bantime = "1h";
      };

      # ── Nginx botsearch jail (scanner detection) ──────────────
      jails.nginx-botsearch.settings = lib.mkIf cfg.nginx.enable {
        enabled = true;

        filter = "nginx-botsearch";
        backend = "auto";

        port = "http,https";
        logpath = "/var/log/nginx/access.log";

        maxretry = 5;
        findtime = "10m";
        bantime = "24h";
      };

      # ── Telegram bot webhook unauthorized access ──────────────
      jails.telegram-webhook.settings = lib.mkIf cfg.bot.enable {
        enabled = true;

        filter = "telegram-webhook";
        backend = "auto";

        port = "https";
        logpath = "/var/log/nginx/access.log";

        maxretry = 5;
        findtime = "5m";
        bantime = "1h";
      };
    };

    # ── Custom filter for Telegram webhook ────────────────────────
    environment.etc."fail2ban/filter.d/telegram-webhook.conf" = lib.mkIf cfg.bot.enable {
      text = ''
        [Definition]
        failregex = ^<HOST> -.*"(GET|POST|HEAD) \/webhook.*" (401|403) .*$
                    ^<HOST> -.*"(GET|POST|HEAD) \/bot[0-9]+:.*" (401|403) .*$
        ignoreregex =
      '';
    };
  };
}
