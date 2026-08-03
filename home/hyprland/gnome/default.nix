##############################################################################
#
# Home — GNOME Applications
#
# Purpose
# -------
# User-level GNOME application configuration on top of the Hyprland desktop:
# Nautilus file manager preferences, the "Open in Terminal" extension
# (open-any-terminal -> kitty), and GTK file-chooser defaults. The packages
# themselves are installed system-wide by desktop/gnome.
#
# Ownership
# ---------
# dconf.settings, com.github.stunkymonkey.nautilus-open-any-terminal
#
# Responsibilities
# ----------------
# - Set Nautilus default view + columns via dconf
# - Point Nautilus "Open in Terminal" at Kitty
# - Apply GTK file-chooser preferences
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

    # Nautilus context menu "Open in Terminal" -> kitty (nautilus-open-any-terminal)
    "com/github/stunkymonkey/nautilus-open-any-terminal" = {
      terminal = "kitty";
    };

    "org/gtk/settings/file-chooser" = {
      sort-directories-first = true;
      show-hidden = false;
    };
  };
}
