# networking/msmtp/default.nix
#
# Outbound email for GitOps notifications via notify.sh.
# Auto-discovered by networking/default.nix — no manual import needed.
#
# Drop additional .nix files here to extend mail configuration:
#   e.g. aliases.nix, logrotate-extra.nix
#
# Requires secrets/smtp.yaml SOPS-encrypted with keys:
#   smtp_password  smtp_host  smtp_user
{ config, pkgs, ... }:
{
  imports = import ../../lib/auto-imports.nix ./.;

  # ── SOPS secrets ────────────────────────────────────────────────────────────
  sops.secrets.smtp_password = {
    sopsFile = ../../secrets/smtp.yaml;
    owner = "root";
    mode = "0400";
  };

  sops.secrets.smtp_host = {
    sopsFile = ../../secrets/smtp.yaml;
    owner = "root";
    mode = "0400";
  };

  sops.secrets.smtp_user = {
    sopsFile = ../../secrets/smtp.yaml;
    owner = "root";
    mode = "0400";
  };

  # ── msmtp (provides the `sendmail` binary that notify.sh calls) ─────────────
  programs.msmtp = {
    enable = true;

    defaults = {
      auth = true;
      tls = true;
      tls_starttls = true;
      logfile = "/var/log/msmtp.log";
    };

    accounts.default = {
      host = "smtp.office365.com";
      port = 587;
      user = "itsivali@outlook.com";
      passwordeval = "cat /run/secrets/smtp_password";
      from = "gitops@prague";
    };
  };

  # ── Log rotation ─────────────────────────────────────────────────────────────
  services.logrotate.settings.msmtp = {
    files = [ "/var/log/msmtp.log" ];
    frequency = "weekly";
    rotate = 4;
    compress = true;
    missingok = true;
    notifempty = true;
  };
}
