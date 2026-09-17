##############################################################################
#
# Desktop — Remote Desktop
#
# Purpose
# -------
# Remote desktop access modules. GRD (GNOME Remote Desktop) is legacy
# for this repository; KRDP (KDE KRDP) is now the canonical RDP server,
# configured in desktop/kde/remote-desktop.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ ... }:

{
  # KRDP remote desktop is configured in desktop/kde/remote-desktop.nix
  # and home/kde/remote-desktop.nix. This barrel exists only to preserve
  # the import chain from desktop/default.nix.
}
