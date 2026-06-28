##############################################################################
#
# AppArmor
#
# Purpose
# -------
# AppArmor mandatory access control.
#
# Ownership
# ---------
# security.apparmor
#
# Does NOT Own
# ------------
# - Sudo (security/sudo.nix)
# - System hardening (security/hardening.nix)
# - Fail2Ban (security/fail2ban.nix)
# - Packages (security/packages.nix)
#
##############################################################################

{ pkgs, ... }:

{
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = false;

    packages = [
      pkgs.apparmor-profiles
    ];
  };
}
