##############################################################################
#
# Locale
#
# Purpose
# -------
# System locale and language settings.
#
# Ownership
# ---------
# i18n.defaultLocale
#
# Does NOT Own
# ------------
# - Time zone (networking/time.nix)
# - Keyboard layout (desktop/)
#
##############################################################################

{ ... }:

{
  i18n.defaultLocale = "en_US.UTF-8";
}
