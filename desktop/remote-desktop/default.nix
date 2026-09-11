##############################################################################
#
# Desktop — Remote Desktop
#
# Purpose
# -------
# Remote desktop access modules: GNOME Remote Desktop (RDP) over Tailscale.
#
# Ownership
# ---------
# services.gnome.gnome-remote-desktop, networking.firewall
#
##############################################################################

{ ... }:

{
  imports = [
    ./grd.nix
  ];
}
