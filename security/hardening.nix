##############################################################################
#
# System Hardening
#
# Purpose
# -------
# Kernel protection, PAM, audit, coredump, and Polkit hardening.
#
# Ownership
# ---------
# security.protectKernelImage, security.lockKernelModules,
# security.rtkit, security.polkit, security.audit, security.auditd,
# security.pam, systemd.coredump
#
# Does NOT Own
# ------------
# - Sudo (security/sudo.nix)
# - AppArmor (security/apparmor.nix)
# - Fail2Ban (security/fail2ban.nix)
# - Packages (security/packages.nix)
# - Firewall (security/firewall.nix)
# - Tailscale (security/tailscale.nix)
#
##############################################################################

{ ... }:

{
  security = {
    protectKernelImage = true;
    lockKernelModules = true;

    rtkit.enable = true;

    polkit = {
      enable = true;

      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }

          return polkit.Result.AUTH_ADMIN;
        });
      '';
    };

    audit.enable = false;
    auditd.enable = false;

    pam = {
      services = {
        login.fprintAuth = false;
        sudo.fprintAuth = false;
      };

      loginLimits = [
        {
          domain = "*";
          type = "hard";
          item = "maxlogins";
          value = "10";
        }
        {
          domain = "*";
          type = "hard";
          item = "core";
          value = "0";
        }
      ];
    };
  };

  systemd.coredump.enable = false;
}
