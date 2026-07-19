##############################################################################
#
# GNOME Shell Theme — gruvbox-waybar
#
# Purpose
# -------
# Custom GNOME Shell CSS loaded by the user-theme extension to give the
# top bar (Dash to Panel) a slim, transparent, Gruvbox "Waybar" look.
#
# Ownership
# ---------
# ~/.local/share/themes/gruvbox-waybar/gnome-shell/gnome-shell.css
# (referenced by org/gnome/shell/extensions/user-theme name = gruvbox-waybar)
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  home.file.".local/share/themes/gruvbox-waybar/gnome-shell/gnome-shell.css" = {
    text = ''
      /* gruvbox-waybar — GNOME Shell top bar (Dash to Panel) */

      @define-color gruvbox-bg rgba(40, 40, 40, 0.55);
      @define-color gruvbox-orange #fe8019;
      @define-color gruvbox-fg #ebdbb2;
      @define-color gruvbox-dim #a89984;

      #panel {
        background-color: @gruvbox-bg;
        border: none;
        border-bottom: 2px solid @gruvbox-orange;
        box-shadow: 0 1px 10px rgba(0, 0, 0, 0.45);
      }

      #panel .panel-button {
        color: @gruvbox-fg;
        font-family: "JetBrains Mono";
        font-size: 11px;
        font-weight: 500;
      }

      #panel .panel-button.clock-display,
      #panel .clock {
        font-family: "JetBrains Mono";
        font-weight: bold;
        color: @gruvbox-orange;
      }

      #panel .panel-button:hover {
        background-color: rgba(254, 128, 25, 0.18);
        box-shadow: none;
      }

      #panel .system-status-icon {
        color: @gruvbox-fg;
      }
    '';
  };
}
