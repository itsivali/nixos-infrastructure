##############################################################################
#
# Journald Configuration
#
# Purpose
# -------
# Persistent journald logging with compression and rate limiting.
# Optimized for low CPU usage.
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
    RateLimitBurst=5000
    SystemMaxUse=50M
    MaxFileSec=1week
    MaxRetentionSec=7day
    Compress=yes
    Seal=no
  '';
}
