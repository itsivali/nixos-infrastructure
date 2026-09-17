##############################################################################
#
# Desktop — Common Environment
#
# Purpose
# -------
# Session environment variables shared by every desktop. XDG_CURRENT_DESKTOP
# and XDG_SESSION_TYPE are set by each desktop environment's own session
# module (GNOME sets "GNOME"/wayland) so portal routing tracks the active
# desktop rather than a hard-coded value.
#
# Ownership
# ---------
# environment.sessionVariables
#
##############################################################################

{ config, lib, ... }:

{
  config = lib.mkIf (config.ivali.desktop.enable or false) {
    environment.sessionVariables = {
      _JAVA_AWT_WM_NONREPARENTING = "1";

      # Route file dialogs through the XDG portal (GTK backend) regardless
      # of the active desktop environment.
      GTK_USE_PORTAL = "1";

      # Ensure Electron/GTK apps use the correct Wayland backend
      NIXOS_OZONE_WL = "1";
    };
  };
}
