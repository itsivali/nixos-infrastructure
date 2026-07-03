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
  # Load profiles as derivations
  ivali-bot-profile = pkgs.writeText "ivali-bot" (builtins.readFile ./profiles/ivali-bot);
  ivali-cli-profile = pkgs.writeText "ivali-cli" (builtins.readFile ./profiles/ivali-cli);
  gitops-reconciler-profile = pkgs.writeText "gitops-reconciler" (builtins.readFile ./profiles/gitops-reconciler);
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

    # Load custom profiles
    policies = {
      ivali-bot = {
        profile =ivali-bot-profile;
        state = "complain";
      };
      ivali-cli = {
        profile =ivali-cli-profile;
        state = "complain";
      };
      gitops-reconciler = {
        profile = gitops-reconciler-profile;
        state = "complain";
      };
    };
  };
}
