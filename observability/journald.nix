##############################################################################
#
# Journald Configuration
#
# Purpose
# -------
# Persistent journald logging with compression and rate limiting.
#
# Ownership
# ---------
# services.journald.extraConfig
#
##############################################################################

{ ... }:

{
  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    ForwardToSyslog=no
    RateLimitIntervalSec=30s
    RateLimitBurst=10000
  '';
}
