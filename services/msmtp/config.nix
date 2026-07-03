##############################################################################
#
# MSMTP — Outbound Email Relay
#
# Purpose
# -------
# Outbound email for GitOps notifications via notify.sh.
#
# Ownership
# ---------
# programs.msmtp, sops.secrets.smtp_*, services.logrotate.settings.msmtp
#
# Dependencies
# ------------
# Requires secrets/smtp.yaml SOPS-encrypted with keys:
#   smtp_password, smtp_host, smtp_user
#
##############################################################################

{ ... }:

{
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

  services.logrotate.settings.msmtp = {
    files = [ "/var/log/msmtp.log" ];
    frequency = "weekly";
    rotate = 4;
    compress = true;
    missingok = true;
    notifempty = true;
  };
}
