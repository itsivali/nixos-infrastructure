##############################################################################
#
# Desktop — Common Platform Gate
#
# Purpose
# -------
# Declare the generic desktop-enable option that gates the shared desktop
# foundation (audio, portals, environment) so it applies to whichever desktop
# environment is active, rather than being coupled to GNOME's enable flag.
#
# Ownership
# ---------
# ivali.desktop.enable
#
# Responsibilities
# ----------------
# - ivali.desktop.enable is set to true by any enabled desktop environment
#   (GNOME) and consumed by the shared common/* modules.
# - Prevent the shared foundation from silently disabling when a host switches
#   from one environment to another.
#
# Usage
# -----
#   ivali.desktop.kde.enable = true;   # sets ivali.desktop.enable = true
#
##############################################################################

{ lib, ... }:

{
  options.ivali.desktop.enable = lib.mkEnableOption "the shared desktop platform (audio, portals, environment)";
}
