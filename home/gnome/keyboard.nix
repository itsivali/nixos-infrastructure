##############################################################################
#
# Home Manager — GNOME Keyboard
#
# Purpose
# -------
# User-level keyboard settings for GNOME. Configures input sources and
# custom keybindings for workspace navigation and app launchers.
#
# Only imported when ivali.desktop.gnome.enable = true.
#
# Ownership
# ---------
# dconf.settings."org/gnome/desktop/input-sources"
# dconf.settings."org/gnome/settings-daemon/plugins/media-keys"
#
##############################################################################

{ config, lib, ... }:

{
  dconf.settings = {
    # ── Input sources ────────────────────────────────────────────────────
    "org/gnome/desktop/input-sources" = {
      sources = [ [ "xkb" "us" ] ];
      options = [ "ctrl:nocaps" ];
    };

    # ── Custom keybindings for workspace navigation ─────────────────────
    "org/gnome/settings-daemon/plugins/media-keys" = {
      # Workspaces already have default keybindings via wm/keybindings;
      # these media keys cover volume, brightness, and screenshot behavior.
      volume-up = [ "<Super>Plus" "<Shift><Super>Plus" ];
      volume-down = [ "<Super>Minus" "<Shift><Super>Minus" ];
      volume-mute = [ "<Super>0" "<Shift><Super>0" ];
      terminal = [ "<Super>T" ];
    };
  };
}
