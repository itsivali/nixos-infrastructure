##############################################################################
#
# Time Zone
#
# Purpose
# -------
# System time zone configuration.
#
# Ownership
# ---------
# time.timeZone
#
# Does NOT Own
# ------------
# - NetworkManager (networking/networkmanager.nix)
# - SSH server (networking/ssh-server.nix)
# - Email relay (networking/msmtp/)
#
##############################################################################

{ ... }:

{
  time.timeZone = "Africa/Nairobi";
}
