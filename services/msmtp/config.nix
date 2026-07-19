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
# programs.msmtp, oauth2ms (OAuth2 token broker),
# services.logrotate.settings.msmtp
#
# Dependencies
# ------------
# Outlook/Office365 SMTP now uses OAuth2 (Microsoft disabled basic auth).
# oauth2ms mints/refreshes the bearer token. One-time manual step as root:
# register an Entra ID public client app, then run
#   sudo oauth2ms --email=<addr> --client-id=<id> --tenant=consumers authorize
# to cache the refresh token in /root/.config/oauth2ms/. Client ID/tenant
# come from config.fleet.notifications.{oauthClientId,oauthTenant}.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet;
  email = if cfg.notifications.email != "" then cfg.notifications.email else "itsivali@outlook.com";
in
{
  # oauth2ms brokers the Outlook/Office365 OAuth2 device-code flow and emits a
  # short-lived access token on stdout for msmtp's passwordeval. Installed
  # globally so it is on PATH for manual `sendmail` use and the GitOps
  # reconciler (which runs sendmail as root).
  environment.systemPackages = [ pkgs.oauth2ms ];

  programs.msmtp = {
    enable = true;
    setSendmail = true;

    defaults = {
      # OAUTHBEARER: msmtp sends the OAuth2 bearer token from oauth2ms
      # instead of a password. Microsoft disabled basic auth (LOGIN/PLAIN) for
      # Exchange Online, which is why the previous password config failed.
      auth = "oauthbearer";
      tls = true;
      tls_starttls = true;
      logfile = "/var/log/msmtp.log";
    };

    accounts.default = {
      host = "smtp.office365.com";
      port = 587;
      # The authenticated mailbox; required by the OAUTHBEARER SASL exchange.
      user = email;
      # oauth2ms reads its cached refresh token from /root/.config/oauth2ms/
      # (populated by the one-time `sudo oauth2ms ... authorize` step) and
      # refreshes/returns an access token for msmtp to use.
      passwordeval = "${pkgs.oauth2ms}/bin/oauth2ms --email=${email} --client-id=${cfg.notifications.oauthClientId} --tenant=${cfg.notifications.oauthTenant}";
      # Office365 rejects a From that is not the authenticated user, so send
      # as the owner's Outlook address (delivered back to the same mailbox).
      from = email;
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
