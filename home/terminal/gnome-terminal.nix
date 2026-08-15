##############################################################################
#
# Home — GNOME Terminal Theming (Gruvbox)
#
# Purpose
# -------
# Applies the Gruvbox design system to GNOME Terminal: JetBrainsMono Nerd
# Font, orange cursor, solid Gruvbox background and the Gruvbox 16-color ANSI
# palette. GNOME Terminal is the sole terminal emulator on the desktop
# (Super+Enter, Nautilus "Open in Terminal", and the MIME terminal handler all
# launch it).
#
# The single source of truth for every color is theme/gruvbox/terminal.nix,
# which derives its palette from theme/gruvbox/colors.nix — nothing is
# hard-coded here.
#
# Ownership
# ---------
# dconf (GNOME Terminal profile)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox/default.nix;
  t = theme.terminal;

  # GNOME Terminal profile UUID (fixed so the dconf paths are stable).
  gnomeProfileId = "b1dcc9dd-5262-4d8d-a863-c897e6d979b9";
in
{
  # ── GNOME Terminal: Gruvbox profile set as the default ──────────────
  # Schema keys verified against gnome-terminal 3.60.0 (pinned nixpkgs rev):
  # per-profile transparency was removed upstream, so the profile uses solid
  # Gruvbox colors + theme-variant "dark" (window opacity is no longer a
  # terminal profile setting).
  dconf.settings."org/gnome/terminal/legacy/profiles:/:${gnomeProfileId}" = {
    visible-name = "Gruvbox";
    use-theme-colors = false;
    background-color = t.background;
    foreground-color = t.foreground;
    cursor-colors-set = true;
    cursor-background-color = t.cursor;
    cursor-foreground-color = t.foreground;
    bold-color = t.selectionBackground;
    palette = t.palette;
    bold-is-bright = false;
    font = "${t.font} ${toString t.fontSize}";
    scrollback-lines = 5000;
    default-size-columns = 110;
  };

  dconf.settings."org/gnome/terminal/legacy" = {
    default-show-menubar = false;
    theme-variant = "dark";
  };

  # The ProfilesList schema lives at `/org/gnome/terminal/legacy/profiles:/`.
  # Home Manager joins the dir and the `default` key with a `/`, so the dir
  # must be `profiles:` (no trailing slash) — otherwise the joined path
  # `profiles://default` is rejected ("two consecutive slashes").
  dconf.settings."org/gnome/terminal/legacy/profiles:" = {
    default = "/org/gnome/terminal/legacy/profiles:/:${gnomeProfileId}";
  };
}
