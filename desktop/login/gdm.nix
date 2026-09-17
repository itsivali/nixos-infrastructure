##############################################################################
#
# Desktop — Login (GDM)
#
# Purpose
# -------
# GDM display manager for GNOME. Wayland-native greeter, greeter theming,
# and boot session selection.
#
# Ownership
# ---------
# services.displayManager.gdm
#
##############################################################################

{ config, lib, ... }:

{
  config = lib.mkIf (config.ivali.desktop.enable or false) {
    # GDM is enabled declaratively in desktop/gnome/session.nix via
    # services.displayManager.gdm.enable = true.
    # This module exists to keep the login/default.nix barrel organized
    # and to document GDM as the canonical display manager for GNOME.
  };
}
