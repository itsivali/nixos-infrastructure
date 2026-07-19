##############################################################################
#
# GNOME Home Manager Configuration
#
# Purpose
# -------
# Home Manager-level GNOME configuration (dconf settings, favorites).
# This is distinct from desktop/gnome/ which configures system-level GNOME.
#
# Ownership
# ---------
# - dconf.nix     — dconf settings for GNOME Shell, desktop, extensions
# - favorites.nix — Dock favorites management
#
# Does NOT Own
# ------------
# - System-level GNOME (desktop/gnome/)
# - GNOME packages (desktop/gnome/packages.nix)
# - GNOME appearance (desktop/gnome/appearance/)
#
##############################################################################

{ ... }:

{
  imports = [
    ./dconf.nix
    ./favorites.nix
    ./shell-theme.nix
  ];
}
