##############################################################################
#
# Home — GNOME
#
# Purpose
# -------
# User-level (Home Manager) configuration for the GNOME desktop: dconf
# settings for GNOME Shell, extensions, and default applications.
#
# Ownership
# ---------
# ivali.desktop.gnome (user side)
#
# Responsibilities
# ----------------
# - Configure GNOME Shell via dconf (workspaces, shortcuts, favorites)
# - Install and configure GNOME extensions
# - Set default application MIME handlers
#
##############################################################################

{ ... }:

{
  imports = [
    ./dconf.nix
    ./extensions.nix
    ./applications.nix
    ./remote-desktop.nix
  ];
}
