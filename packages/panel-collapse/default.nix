##############################################################################
#
# Package — GNOME Shell "Panel Collapse" Extension
#
# Purpose
# -------
# A tiny GNOME Shell extension that hides the non-essential right-side panel
# indicators (quick settings, vitals gauges, clipboard indicator and AppIndicator
# tray icons) behind a chevron arrow, so the date and time stay permanently
# visible on the minimal dash-to-panel top bar.
#
# Behavior
# --------
# - Adds a chevron button (» / «) at the right end of the top panel.
# - Collapsed (default at login): only the clock is visible next to the arrow.
# - Clicking the arrow reveals/hides: quick settings (systemMenu), vitals,
#   clipboard-indicator and any AppIndicator tray icons.
# - New tray icons that appear while collapsed (e.g. an app registers an
#   indicator) are hidden automatically; the indicators keep running underneath.
# - State persists in GSettings (org.gnome.shell.extensions.panel-collapse),
#   so the collapsed/expanded choice survives shell restarts.
#
# How it works
# ------------
# dash-to-panel replaces the stock top bar: the third-party indicators
# (vitals, clipboard-indicator, appindicator) are registered through
# Main.panel.addToStatusArea and end up as children of Main.panel._rightBox,
# while the quick settings button is a direct panel child stored as
# Main.panel.statusArea.quickSettings.container. This extension toggles the
# `visible` property of those actors and keeps Main.panel.statusArea.dateMenu
# (the clock) always visible.
#
# Usage
# -----
# System-wide install via environment.systemPackages (desktop/gnome/extensions.nix),
# enabled per-user via org.gnome.shell.enabled-extensions with its own dconf
# settings under org/gnome/shell/extensions/panel-collapse (home/gnome/extensions.nix).
#
# Troubleshooting
# ---------------
# - Nothing collapsed: confirm the extension is enabled (gnome-extensions list)
#   and that `collapsed = true` in dconf.
# - Quick settings still visible: dash-to-panel must own the panel; if the stock
#   panel is used the entry lives at Main.panel.statusArea.quickSettings the same
#   way, so it still collapses.
# - Shell restart is required after install (extensions load at login).
#
##############################################################################

{ stdenv, glib }:

stdenv.mkDerivation {
  pname = "gnome-shell-extension-panel-collapse";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [ glib ];

  installPhase = ''
    runHook preInstall
    install -d $out/share/gnome-shell/extensions/panel-collapse@ivali/schemas
    install -m 0644 extension.js metadata.json \
      $out/share/gnome-shell/extensions/panel-collapse@ivali/
    install -m 0644 schemas/*.gschema.xml \
      $out/share/gnome-shell/extensions/panel-collapse@ivali/schemas/
    glib-compile-schemas \
      $out/share/gnome-shell/extensions/panel-collapse@ivali/schemas
    install -d $out/share/doc/panel-collapse
    install -m 0644 README.md $out/share/doc/panel-collapse/
    runHook postInstall
  '';
}
