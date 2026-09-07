##############################################################################
#
# Home — XFCE MIME Handlers
#
# Purpose
# -------
# Desktop-specific XDG MIME associations for the XFCE stack: which
# application opens each content type. Complements the shared MIME defaults
# in home/environment/mime.nix (web + media) with the XFCE-native handlers.
#
# Ownership
# ---------
# xdg.mimeApps.defaultApplications (XFCE subset)
#
# Responsibilities
# ----------------
# - File manager  -> Thunar
# - Images        -> Ristretto
# - PDF           -> evince
# - Archives      -> Xarchiver
# - Text          -> Mousepad
# - Terminal      -> xfce4-terminal
#
##############################################################################

{ lib, ... }:

{
  xdg.mimeApps.defaultApplications = {
    # ── File manager ─────────────────────────────────────────────────────
    "inode/directory" = "thunar.desktop";

    # ── Images ───────────────────────────────────────────────────────────
    "image/*" = "org.xfce.ristretto.desktop";

    # ── Documents ────────────────────────────────────────────────────────
    "application/pdf" = "org.gnome.Evince.desktop";

    # ── Archives ─────────────────────────────────────────────────────────
    "application/zip" = "xarchiver.desktop";
    "application/x-tar" = "xarchiver.desktop";
    "application/gzip" = "xarchiver.desktop";
    "application/x-compressed-tar" = "xarchiver.desktop";
    "application/x-bzip-compressed-tar" = "xarchiver.desktop";
    "application/x-xz-compressed-tar" = "xarchiver.desktop";
    "application/x-7z-compressed" = "xarchiver.desktop";
    "application/x-rar-compressed" = "xarchiver.desktop";
    "application/vnd.rar" = "xarchiver.desktop";
    "application/x-bzip" = "xarchiver.desktop";
    "application/x-lzip" = "xarchiver.desktop";
    "application/x-lz4" = "xarchiver.desktop";
    "application/x-lzma" = "xarchiver.desktop";
    "application/x-lzo" = "xarchiver.desktop";
    "application/x-zstd-compressed-tar" = "xarchiver.desktop";

    # ── Text ─────────────────────────────────────────────────────────────
    "text/plain" = "org.xfce.mousepad.desktop";

    # ── Terminal ─────────────────────────────────────────────────────────
    "x-scheme-handler/terminal" = "xfce4-terminal.desktop";
  };
}
