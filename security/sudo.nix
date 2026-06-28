##############################################################################
#
# Sudo
#
# Purpose
# -------
# Sudo configuration and hardening.
#
# Ownership
# ---------
# security.sudo
#
# Does NOT Own
# ------------
# - Kernel hardening (security/hardening.nix)
# - AppArmor (security/apparmor.nix)
# - Fail2Ban (security/fail2ban.nix)
# - Packages (security/packages.nix)
#
##############################################################################

{ ... }:

{
  security.sudo = {
    enable = true;
    execWheelOnly = true;

    extraConfig = ''
      Defaults timestamp_timeout=5
      Defaults passwd_tries=3
      Defaults use_pty
      Defaults logfile="/var/log/sudo.log"
    '';
  };
}
