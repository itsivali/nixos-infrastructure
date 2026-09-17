##############################################################################
#
# Desktop — Login
#
# Purpose
# -------
# Barrel for display-manager / login-screen modules.
# GDM is the canonical display manager for GNOME.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ ... }:

{
  imports = [
    ./gdm.nix
  ];
}
