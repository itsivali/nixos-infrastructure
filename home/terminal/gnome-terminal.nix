##############################################################################
#
# Home — GNOME Terminal Theming (Mokka)
#
# Purpose
# -------
# Applies the Garuda "Mokka" look (Catppuccin-Mocha palette,
# JetBrainsMono Nerd Font, red block cursor, 90% opacity) to GNOME Terminal.
#
#   - Kitty            → see ./kitty.nix (the default terminal)
#   - GNOME Terminal   → dconf profile ("Mokka", default profile)
#
# The single source of truth for every color is theme/gruvbox/mokka.nix;
# the GNOME Terminal profile is generated from that slice so it cannot drift.
#
# Ownership
# ---------
# programs.kitty (./kitty.nix), dconf (GNOME Terminal)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox/default.nix;
  m = theme.mokka;

  # GNOME Terminal profile UUID (fixed so the dconf paths are stable).
  gnomeProfileId = "b1dcc9dd-5262-4d8d-a863-c897e6d979b9";
in
{
  # ── GNOME Terminal: Mokka profile set as the default ──────────────
  dconf.settings."org/gnome/terminal/legacy/profiles:/:${gnomeProfileId}" = {
    visible-name = "Mokka";
    use-theme-colors = false;
    background-color = m.background;
    foreground-color = m.foreground;
    cursor-color = m.cursor;
    bold-color = m.selectionBackground;
    palette = m.palette;
    use-transparent-background = true;
    background-transparency-percent = 10;
    bold-is-bright = false;
    font = "${m.font} ${toString m.fontSize}";
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
