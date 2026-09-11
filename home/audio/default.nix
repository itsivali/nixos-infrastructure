##############################################################################
#
# Home — Audio
#
# Purpose
# -------
# User-level audio configuration: EasyEffects volume boost service
# and preset for safe, controlled loudness.
#
# Ownership
# ---------
# systemd.user.services.easyeffects, home.file (EasyEffects preset)
#
# Responsibilities
# ----------------
# - EasyEffects output preset (volume gain + limiter)
# - systemd user service to run EasyEffects at login
#
##############################################################################

{ ... }:

{
  imports = [
    ./boost.nix
  ];
}
