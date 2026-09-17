##############################################################################
#
# Desktop — Login (SDDM)
#
# Purpose
# -------
# SDDM display manager for KDE Plasma 6. Wayland-native greeter,
# greeter theming, and boot session selection.
#
# Ownership
# ---------
# services.displayManager.sddm
#
##############################################################################

{ config, lib, ... }:

{
  config = lib.mkIf (config.ivali.desktop.enable or false) {
    # SDDM is enabled declaratively in desktop/kde/session.nix via
    # services.displayManager.sddm.enable = true.
    # This module exists to keep the login/default.nix barrel organized
    # and to document SDDM as the canonical display manager.
  };
}
