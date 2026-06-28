##############################################################################
#
# Fail2Ban
#
# Purpose
# -------
# Brute-force protection for SSH and other services.
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

{ ... }:

{
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
  };
}
