##############################################################################
#
# Home — Spotlight Application Launcher
#
# Purpose
# -------
# Fast keyboard-first application launcher independent of GNOME Search.
# fuzzel is a lightweight, Wayland-native launcher that satisfies the
# IVALi Desktop spec:
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
# programs.fuzzel, dconf.settings."org/gnome/settings-daemon/plugins/media-keys",
# dconf.settings."org/gnome/desktop/wm/keybindings"
#
# Responsibilities
# ----------------
# - Install and theme fuzzel (Gruvbox palette)
# - Bind Super+Space to launch the launcher
# - Free Super+Space from GNOME's default input-source keybinding so the
#   shortcut is available without conflict
#
##############################################################################

{ pkgs, lib, ... }:

let
  theme = import ../../theme/gruvbox;
  c = theme.colors;
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "${theme.fonts.monospace}:size=12";
        width = 34;
        lines = 15;
        horizontal-pad = 16;
        vertical-pad = 10;
        prompt = "❯ ";
        dpi-aware = "no";
        icon-theme = theme.icons.name;
        show-actions = false;
        layer = "overlay";
      };

      border = {
        radius = 8;
        width = 2;
      };

      colors = {
        background = "${c.bgSoft}ee";
        text = "${c.fg}ff";
        prompt = "${c.orange}ff";
        match = "${c.orange}ff";
        selection = "${c.bg2}ff";
        selection-text = "${c.fg}ff";
        selection-match = "${c.yellow}ff";
        border = "${c.orange}66";
      };

      dmenu = {
        exit-immediately-if-empty = false;
      };
    };
  };

  dconf.settings = {
    # ── Free Super+Space from GNOME's default input-source switching ────
    # GNOME binds Super+Space to switch-input-source. Clear both so the
    # Spotlight keybinding below is the sole owner of the shortcut.
    "org/gnome/desktop/wm/keybindings" = {
      switch-input-source = [ ];
      switch-input-source-backward = [ ];
    };

    # ── Spotlight launcher (Super+Space) ────────────────────────────────
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Spotlight (fuzzel)";
      command = "${pkgs.fuzzel}/bin/fuzzel";
      binding = "<Super>space";
    };
  };
}
