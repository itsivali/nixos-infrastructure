##############################################################################
#
# Desktop — Login (Ly)
#
# Purpose
# -------
# Gruvbox-themed Ly TUI display manager. Replaces GDM entirely. Runs on
# the Linux console (VT1) with true-color styling, terminal-based font,
# and auto-discovery of Wayland sessions (Hyprland) via
# services.displayManager.sessionData.
#
# Ownership
# ---------
# services.displayManager.ly
#
# Responsibilities
# ----------------
# - Present a themed login screen on the console
# - Discover and launch the Hyprland Wayland session
# - Handle shutdown/restart + brightness keys from the login screen
#
# Notes
# -----
# - Ly has NO font option: it renders in the console font (see
#   desktop/common/fonts.nix → console.font). Nerd Fonts are not
#   supported on the VT.
# - Color format is 0xSSRRGGBB (SS = style byte, see toLy/toLyBold in
#   theme/gruvbox/colors.nix). 0x00000000 = terminal default.
# - Do NOT set waylandsessions/xsessions here: they are injected by the
#   nixpkgs module from sessionData.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  gruvbox = import ../../theme/gruvbox/default.nix;
  lyTheme = gruvbox.ly;
in
{
  config = lib.mkIf (config.ivali.desktop.hyprland.enable or false) {
    services.displayManager.ly = {
      enable = true;

      settings = {
        # ── Gruvbox colors ────────────────────────────────────────────────
        bg = lyTheme.bg;
        fg = lyTheme.fg;
        border_fg = lyTheme.border_fg;
        error_fg = lyTheme.error_fg;
        colormix_col1 = lyTheme.colormix_col1;
        colormix_col2 = lyTheme.colormix_col2;
        colormix_col3 = lyTheme.colormix_col3;

        # ── Appearance ────────────────────────────────────────────────────
        animate = true;
        animation = "colormix";
        hide_borders = true;
        hide_key_hints = true;
        hide_version_string = true;
        clear_password = true;
        lang = "en";

        # ── Clock ─────────────────────────────────────────────────────────
        clock = "%A, %B %d — %H:%M";
      };
    };

    # Boot straight into the Hyprland session (only session installed).
    services.displayManager.defaultSession = "hyprland";

    # PAM keyring support for the login session (matches what Ly expects).
    services.gnome.gnome-keyring.enable = lib.mkDefault true;
  };
}
