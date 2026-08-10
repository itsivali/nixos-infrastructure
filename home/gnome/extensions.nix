##############################################################################
#
# Home — GNOME Shell Extensions
#
# Purpose
# -------
# Per-user enablement + preferences for the curated GNOME Shell extension set
# (packages installed by desktop/gnome/extensions.nix). Extension packages do
# not expose their UUIDs in nixpkgs, so the UUIDs below were extracted from
# each extension's metadata.json at the pinned nixpkgs revision.
#
# Ownership
# ---------
# dconf.settings."org/gnome/shell".enabled-extensions,
# dconf.settings."org/gnome/shell/extensions/*"
#
# Extension UUID reference
# ------------------------
#   dash-to-dock                  dash-to-dock@micxgx.gmail.com
#   blur-my-shell                 blur-my-shell@aunetx
#   appindicator                  appindicatorsupport@rgcjonas.gmail.com
#   user-themes                   user-theme@gnome-shell-extensions.gcampax.github.com
#   just-perfection               just-perfection-desktop@just-perfection
#   tiling-assistant              tiling-assistant@leleat-on-github
#   clipboard-indicator           clipboard-indicator@tudmotu.com
#   sound-output-device-chooser   sound-output-device-chooser@kgshank.net
#   impatience                    impatience@gfxmonk.net
#   battery-time                  batime@martin.zurowietz.de
#
# Every value below was cross-checked against the extension GSettings schema
# at the pinned nixpkgs revision (see the schema dumps in the migration notes).
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "dash-to-dock@micxgx.gmail.com"
        "blur-my-shell@aunetx"
        "appindicatorsupport@rgcjonas.gmail.com"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "just-perfection-desktop@just-perfection"
        "tiling-assistant@leleat-on-github"
        "clipboard-indicator@tudmotu.com"
        "sound-output-device-chooser@kgshank.net"
        "impatience@gfxmonk.net"
        "batime@martin.zurowietz.de"
      ];
    };

    # ── dash-to-dock: fixed macOS-style dock at the bottom ──────────────
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-fixed = true;
      dock-position = "BOTTOM";
      dash-max-icon-size = 48;
      height-fraction = 0.9;
      show-running = true;
    };

    # ── blur-my-shell: frost the panel + dock (Gruvbox translucency) ───
    # Global enable is on by default; declared explicitly so a settings
    # reset cannot silently disable it. Panel keeps the default sigma 30.
    "org/gnome/shell/extensions/blur-my-shell" = {
      blur = true;
      sigma = 30;
      brightness = 0.6;
    };

    # ── user-theme: load the Gruvbox Shell theme (from the custom package
    #    packages/gnome-shell-gruvbox-theme, installed via home.packages) ─
    "org/gnome/shell/extensions/user-theme" = {
      name = "gruvbox-shell";
    };

    # ── just-perfection: declutter the overview ──────────────────────────
    # Boot straight to the desktop (no overview), hide the window-picker
    # icon clutter, keep the dash (dash-to-dock owns the dock).
    "org/gnome/shell/extensions/just-perfection" = {
      startup-status = 0;
      window-picker-icon = false;
    };

    # ── tiling-assistant: comfortable window gaps ────────────────────────
    "org/gnome/shell/extensions/tiling-assistant" = {
      window-gap = 8;
      single-screen-gap = 8;
      maximize-with-gap = true;
    };

    # ── clipboard-indicator: clipboard history ──────────────────────────
    "org/gnome/shell/extensions/clipboard-indicator" = {
      history-size = 50;
      cache-images = true;
      paste-button = true;
      notify-on-copy = false;
    };

    # ── sound-output-device-chooser: fold sinks/sources into the volume
    #    quick-settings slider (no separate tray icon) ─────────────────────
    "org/gnome/shell/extensions/sound-output-device-chooser" = {
      integrate-with-slider = true;
    };

    # ── impatience: 4x faster Shell animations (0.25 vs default 0.75) ───
    "org/gnome/shell/extensions/net/gfxmonk/impatience" = {
      speed-factor = 0.25;
    };

    # battery-time has no GSettings schema at this rev; it uses its own
    # defaults (battery % + time remaining in the top bar). No dconf here.
  };
}
