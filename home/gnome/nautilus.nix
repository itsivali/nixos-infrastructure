##############################################################################
#
# Home — GNOME Applications (Nautilus & friends)
#
# Purpose
# -------
# Per-user GNOME application configuration: Nautilus file manager preferences,
# the "Open in Terminal" extension (open-any-terminal -> gnome-terminal), and
# GTK file-chooser defaults. The packages themselves are installed system-wide
# by desktop/gnome/session.nix.
#
# Ownership
# ---------
# dconf.settings, com.github.stunkymonkey.nautilus-open-any-terminal
#
# Responsibilities
# ----------------
# - Set Nautilus default view + columns via dconf
# - Point Nautilus "Open in Terminal" at GNOME Terminal
# - Apply GTK file-chooser preferences
#
# Notes
# -----
# Migrated verbatim from the former home/hyprland/gnome module when Hyprland
# was retired in favor of GNOME.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
      show-hidden-files = false;
      mouse-back-button-to-go-back = true;
    };

    "org/gnome/nautilus/list-view" = {
      default-visible-columns = [ "name" "size" "date_modified" ];
      default-zoom-level = "small";
    };

    # Nautilus context menu "Open in Terminal" -> gnome-terminal
    # (nautilus-open-any-terminal)
    "com/github/stunkymonkey/nautilus-open-any-terminal" = {
      terminal = "gnome-terminal";
    };

    "org/gtk/settings/file-chooser" = {
      sort-directories-first = true;
      show-hidden = false;
    };
  };
}
