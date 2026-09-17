##############################################################################
#
# Desktop — KDE Keyboard
#
# Purpose
# -------
# Keyboard layout and modifier mappings for keyboard-first daily use.
#
# Ownership
# ---------
# services.xserver.xkb
#
# Notes
# -----
# Plasma also reads this xkb configuration for the Wayland session;
# per-session key-repeat tuning lives in home/kde (plasma-manager).
#
##############################################################################

{ config, lib, ... }:

{
  config = lib.mkIf (config.ivali.desktop.kde.enable or false) {
    services.xserver.xkb = {
      layout = "us";
      options = "ctrl:nocaps";
    };
  };
}
