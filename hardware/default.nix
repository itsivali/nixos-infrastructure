##############################################################################
#
# Hardware Module
#
# Purpose
# -------
# Hardware-level configuration: USB power management, device quirks,
# and platform-specific fixes.
#
# Ownership
# ---------
# Hardware domain: USB controller power states, device quirks
#
# Does NOT Own
# ------------
# - Kernel parameters (boot/kernel.nix)
# - Security policies (security/*)
# - Audio stack (desktop/common/audio.nix)
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
