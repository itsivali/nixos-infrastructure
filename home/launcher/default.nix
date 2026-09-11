##############################################################################
#
# Home — Spotlight Application Launcher
#
# Purpose
# -------
# Fast keyboard-first application launcher independent of GNOME Search.
# Search Light is a GNOME Shell extension that provides a Spotlight-like
# fuzzy search overlay, satisfying the IVALi Desktop spec:
#   * instant open (no search daemon, no indexer)
#   * application discovery via XDG desktop entries with icons
#   * Enter to launch, arrow-key navigation, fuzzy matching
#   * Gruvbox styling that matches the desktop
#
# The intended application hierarchy is:
#   ArcMenu        → graphical application browsing
#   Spotlight      → fast keyboard launching (Super+Space)
#   GNOME Overview → windows / workspaces
#
# Ownership
# ---------
# dconf.settings."org/gnome/shell/extensions/search-light"
#
# Notes
# -----
# Search Light runs natively within GNOME Shell (no external process).
# It uses the GNOME Shell extension framework, avoiding the wlr-layer-shell
# dependency that fuzzel requires. This makes it compatible with Mutter.
#
##############################################################################

{ lib, ... }:

let
  # Gruvbox Dark RGB doubles for Search Light schema (dddd tuples)
  # bg=#282828  fg=#ebdbb2  orange=#fe8019
  bg = lib.hm.gvariant.mkTuple [
    (lib.hm.gvariant.mkDouble 0.157)
    (lib.hm.gvariant.mkDouble 0.157)
    (lib.hm.gvariant.mkDouble 0.157)
    (lib.hm.gvariant.mkDouble 0.95)
  ];
  fg = lib.hm.gvariant.mkTuple [
    (lib.hm.gvariant.mkDouble 0.922)
    (lib.hm.gvariant.mkDouble 0.859)
    (lib.hm.gvariant.mkDouble 0.698)
    (lib.hm.gvariant.mkDouble 1.0)
  ];
  orange = lib.hm.gvariant.mkTuple [
    (lib.hm.gvariant.mkDouble 0.996)
    (lib.hm.gvariant.mkDouble 0.502)
    (lib.hm.gvariant.mkDouble 0.098)
    (lib.hm.gvariant.mkDouble 1.0)
  ];
in
{
  dconf.settings = {
    # ── Free Super+Space from GNOME's default input-source switching ────
    # GNOME binds Super+Space to switch-input-source. Clear both so the
    # Search Light keybinding below is the sole owner of the shortcut.
    "org/gnome/desktop/wm/keybindings" = {
      switch-input-source = [ ];
      switch-input-source-backward = [ ];
    };

    # ── Search Light (Spotlight replacement) ────────────────────────────
    # Gruvbox-themed fuzzy search overlay triggered by Super+Space.
    # Runs as a GNOME Shell extension — no external process, no
    # wlr-layer-shell dependency.
    "org/gnome/shell/extensions/search-light" = {
      shortcut-search = [ "<Super>space" ];
      show-panel-icon = false;

      # Gruvbox color palette
      background-color = bg;
      text-color = fg;
      border-color = orange;

      border-radius = lib.hm.gvariant.mkDouble 8.0;
      border-thickness = 2;
      font-size = 14;
    };
  };
}
