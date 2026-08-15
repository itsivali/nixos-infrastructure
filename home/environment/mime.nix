##############################################################################
#
# MIME Type Default Applications
#
# Purpose
# -------
# Declarative XDG MIME associations: which application opens each content
# type. Keeps the GTK/GNOME application stack the default across the whole
# desktop (browser, file manager, image viewer, PDF viewer, archive manager,
# text editor, terminal).
#
# Ownership
# ---------
# xdg.mimeApps
#
# Responsibilities
# ----------------
# - Map content types to the GNOME/GTK application stack
# - Route http(s) to Firefox and directories to Nautilus
# - Bind text/plain to GNOME Text Editor and x-scheme-handler/terminal to GNOME Terminal
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

    # ── File manager ─────────────────────────────────────────────────────
    "inode/directory" = "org.gnome.Nautilus.desktop";

    # ── Images ───────────────────────────────────────────────────────────
    "image/*" = "org.gnome.Loupe.desktop";

    # ── Documents ────────────────────────────────────────────────────────
    "application/pdf" = "org.gnome.Papers.desktop";

    # ── Archives ─────────────────────────────────────────────────────────
    "application/zip" = "org.gnome.FileRoller.desktop";
    "application/x-tar" = "org.gnome.FileRoller.desktop";
    "application/gzip" = "org.gnome.FileRoller.desktop";
    "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
    "application/x-bzip-compressed-tar" = "org.gnome.FileRoller.desktop";
    "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
    "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
    "application/x-rar-compressed" = "org.gnome.FileRoller.desktop";
    "application/vnd.rar" = "org.gnome.FileRoller.desktop";
    "application/x-bzip" = "org.gnome.FileRoller.desktop";
    "application/x-lzip" = "org.gnome.FileRoller.desktop";
    "application/x-lz4" = "org.gnome.FileRoller.desktop";
    "application/x-lzma" = "org.gnome.FileRoller.desktop";
    "application/x-lzo" = "org.gnome.FileRoller.desktop";
    "application/x-zstd-compressed-tar" = "org.gnome.FileRoller.desktop";

    # ── Media (mpv) ────────────────────────────────────────────────────
    "video/*" = "mpv.desktop";
    "audio/*" = "mpv.desktop";

    # ── Text ─────────────────────────────────────────────────────────────
    "text/plain" = "org.gnome.TextEditor.desktop";

    # ── Terminal ─────────────────────────────────────────────────────────
    "x-scheme-handler/terminal" = "org.gnome.Terminal.desktop";
  };
}
