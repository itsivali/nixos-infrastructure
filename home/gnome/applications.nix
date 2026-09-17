##############################################################################
#
# Home Manager — GNOME Default Applications
#
# Purpose
# -------
# Desktop-specific XDG MIME associations for the GNOME stack: which
# application opens each content type. Complements the shared MIME
# defaults in home/environment/mime.nix (web + media) with GNOME-native
# handlers.
#
# Ownership
# ---------
# xdg.mimeApps.defaultApplications
#
##############################################################################

{ lib, ... }:

{
  xdg.mimeApps.defaultApplications = {
    # File manager
    "inode/directory" = "org.gnome.Nautilus.desktop";

    # Images
    "image/*" = "org.gnome.eog.desktop";

    # Documents
    "application/pdf" = "org.gnome.Evince.desktop";

    # Text
    "text/plain" = "org.gnome.TextEditor.desktop";
    "text/csv" = "org.gnome.TextEditor.desktop";

    # Terminal
    "x-scheme-handler/terminal" = "org.gnome.Console.desktop";
  };
}
