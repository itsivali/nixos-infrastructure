##############################################################################
#
# Home — GNOME
#
# Purpose
# -------
# Barrel for the per-user GNOME desktop configuration. Everything here is
# strictly unprivileged and declarative (dconf only — no system services).
#
# Ownership
# ---------
# dconf.settings
#
# Responsibilities
# ----------------
# - Nautilus file manager + "Open in Terminal" preferences (nautilus.nix)
# - GNOME Shell extension enablement + per-extension preferences
#   (extensions.nix)
# - GNOME Shell behavior: favorites, keybindings, touchpad, power, wallpaper,
#   accessibility (shell.nix)
#
# Notes
# -----
# This module is imported by home/default.nix when the host enables
# ivali.desktop.gnome. The extension *packages* are installed system-wide by
# desktop/gnome/extensions.nix; only the per-user enablement lives here.
#
##############################################################################

{ ... }:

{
  imports = [
    ./nautilus.nix
    ./extensions.nix
    ./shell.nix
  ];
}
