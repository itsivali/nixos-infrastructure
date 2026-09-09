##############################################################################
#
# MIME Type Default Applications
#
# Purpose
# -------
# Declarative XDG MIME associations: which application opens each content
# type. Routes http(s) to Firefox and media to mpv; the remaining stack
# (file manager, image viewer, PDF viewer, archive manager, text editor,
# terminal) follows the active desktop environment via the desktop-specific
# handler modules (GNOME -> home/gnome).
#
# Ownership
# ---------
# xdg.mimeApps
#
# Responsibilities
# ----------------
# - Map content types to the desktop-independent application stack
# - Route http(s) to Firefox and media to mpv
# - Desktop-specific handlers (file manager, image, pdf, text, terminal,
#   archives) are declared by the active desktop's Home Manager module
#
##############################################################################

{ lib, ... }:

{
  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = {
    # ── Web ──────────────────────────────────────────────────────────────
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "application/xhtml+xml" = "firefox.desktop";

    # ── Media (mpv) ────────────────────────────────────────────────────
    "video/*" = "mpv.desktop";
    "audio/*" = "mpv.desktop";
  };
}
