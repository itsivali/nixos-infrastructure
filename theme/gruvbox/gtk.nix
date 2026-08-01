##############################################################################
#
# Theme — Gruvbox GTK
#
# Purpose
# -------
# GTK/icon/cursor theme names consumed by GTK3/GTK4, Electron and Firefox.
# Cursor and icon names derive from their dedicated slices to keep a single
# source of truth. Package selection happens at the consumer (package names
# differ per layer).
#
# Ownership
# ---------
# theme.gruvbox.gtk
#
##############################################################################

{ cursor, icons }:

{
  theme = "adw-gtk3-dark";
  cursorTheme = cursor.name;
  cursorSize = cursor.size;
  iconTheme = icons.name;
}
