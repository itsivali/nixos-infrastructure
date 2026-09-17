##############################################################################
#
# Desktop — Remote Desktop
#
# Purpose
# -------
# Remote desktop access modules. GNOME Remote Desktop (GRD) is the canonical
# RDP/VNC server for this repository, configured in desktop/gnome/remote-desktop.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ ... }:

{
  # GNOME Remote Desktop is configured in desktop/gnome/remote-desktop.nix.
  # This barrel exists only to preserve the import chain from desktop/default.nix.
}
