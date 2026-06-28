##############################################################################
#
# Security Packages and Tempfiles
#
# Purpose
# -------
# Install security-related system packages and tempfiles rules.
#
# Ownership
# ---------
# environment.systemPackages (security), systemd.tmpfiles.rules
#
# Does NOT Own
# ------------
# - Sudo (security/sudo.nix)
# - System hardening (security/hardening.nix)
# - AppArmor (security/apparmor.nix)
# - Fail2Ban (security/fail2ban.nix)
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    aide
    audit
    lynis
    apparmor-utils
    apparmor-parser
    nftables
    tcpdump
    lsof
    strace
    usbutils
    pciutils
  ];

  systemd.tmpfiles.rules = [
    "d /var/log/audit 0750 root root -"
    "f /var/log/sudo.log 0600 root root -"
  ];
}
