##############################################################################
#
# Home — Shared Desktop Theming
#
# Purpose
# -------
# GTK and font configuration shared across all desktops.
# Uses GNOME/Adwaita defaults for theme, icons, and cursor.
# Single source of truth for GTK appearance and font settings.
#
# Ownership
# ---------
# gtk.enable, gtk.font, gtk.gtk3.extraConfig,
# dconf.settings."org/gnome/desktop/interface"
#
# Does NOT Own
# ------------
# - Cursor/icon theme (GNOME/Adwaita defaults — no override needed)
# - XCURSOR_* environment variables (removed — GNOME handles this natively)
# - Per-desktop dconf overrides (home/gnome/desktop.nix owns those)
#
##############################################################################

{ config, lib, ... }:

{
  gtk = {
    enable = true;

    font = {
      name = "Inter";
      size = 10;
    };

    # No gtk.theme, gtk.iconTheme, or gtk.cursorTheme overrides.
    # GTK defaults to Adwaita-dark when color-scheme = "prefer-dark".
    # GNOME handles cursor and icon themes natively via dconf.

    gtk3.extraConfig = {
      "gtk-application-prefer-dark-theme" = 1;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    accent-color = "mauve";
    font-antialiasing = "rgba";
    font-hinting = "full";
  };
}
