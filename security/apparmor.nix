##############################################################################
#
# AppArmor
#
# Purpose
# -------
# AppArmor mandatory access control with custom profiles for
# infrastructure components.
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
# Profiles
# --------
# - ivali-bot: Telegram bot process
# - ivali-cli: Go CLI binary
# - gitops-reconciler: GitOps reconciliation service
#
# All profiles start in complain mode for safe deployment.
# To enforce a profile after validation:
#   aa-enforce /etc/apparmor.d/<profile>
#
##############################################################################

{ pkgs, lib, ... }:

let
  # Helper to create an AppArmor profile
  mkProfile = name: path: {
    profile = builtins.readFile path;
    state = "complain";
  };
in
{
  security.apparmor = {
    enable = true;

    # Don't kill processes that are confined but not yet profiled
    killUnconfinedConfinables = false;

    packages = [
      pkgs.apparmor-profiles
      pkgs.apparmor-utils
      pkgs.apparmor-parser
    ];

    # Load custom profiles from the security/apparmor/profiles/ directory
    policies = {
      ivali-bot = mkProfile "ivali-bot" ./profiles/ivali-bot;
      ivali-cli = mkProfile "ivali-cli" ./profiles/ivali-cli;
      gitops-reconciler = mkProfile "gitops-reconciler" ./profiles/gitops-reconciler;
    };
  };
}
