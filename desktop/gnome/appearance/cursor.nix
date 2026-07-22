##############################################################################
#
# Desktop GNOME Appearance Cursor
#
# Purpose
# -------
# Sets the GNOME cursor theme and size via session environment variables.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Set XCURSOR_THEME to Bibata-Modern-Ice
# - Set XCURSOR_SIZE to 24
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
    };
  };
}
