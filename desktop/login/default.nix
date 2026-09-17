##############################################################################
#
# Desktop — Login
#
# Purpose
# -------
# Barrel for display-manager / login-screen modules.
# SDDM is the canonical display manager for KDE Plasma 6.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ ... }:

{
  imports = [
    ./sddm.nix
  ];
}
