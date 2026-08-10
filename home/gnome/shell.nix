##############################################################################
#
# Home — GNOME Shell Behavior
#
# Purpose
# -------
# Per-user GNOME Shell + desktop behavior: dock favorites, keybindings,
# touchpad, power/idle policy for the laptop, Gruvbox wallpaper, and
# accessibility defaults.
#
# Ownership
# ---------
# dconf.settings."org/gnome/*"
#
# Schema notes
# ------------
# All keys verified against the GNOME 50 (pinned rev) GSettings schemas:
#   - org.gnome.desktop.background.picture-uri-dark  (GNOME 46+)
#   - org.gnome.desktop.a11y.*                       (stickykeys-enable,
#     slowkeys-enable — note the spelling without hyphen)
#   - org.gnome.desktop.wm.preferences.button-layout
# Power/idle keys live in org.gnome.settings-daemon.plugins.power (a
# decade-stable schema; validated by the full toplevel build).
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  dconf.settings = {
    # ── Dock favorites (launcher order) ────────────────────────────────
    # Kitty is the terminal; firefox the browser; the rest are the GNOME
    # core apps. dash-to-dock's favorites read this same list.
    "org/gnome/shell" = {
      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "kitty.desktop"
        "firefox.desktop"
        "org.gnome.TextEditor.desktop"
        "org.gnome.Calculator.desktop"
        "org.gnome.Loupe.desktop"
        "org.gnome.Papers.desktop"
        "org.gnome.SystemMonitor.desktop"
      ];
    };

    # ── Window manager ─────────────────────────────────────────────────
    # macOS-style minimize/maximize window buttons + close on Meta+Q.
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
    };

    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" "<Alt>F4" ];
    };

    # ── Custom app launchers ───────────────────────────────────────────
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Terminal";
      command = "kitty";
      binding = "<Super>Return";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name = "Web Browser";
      command = "firefox";
      binding = "<Super>b";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      name = "Files";
      command = "nautilus";
      binding = "<Super>e";
    };

    # ── Touchpad (laptop) ──────────────────────────────────────────────
    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = true;
      natural-scroll = true;
      two-finger-scrolling-enabled = true;
    };

    # ── Power / idle (laptop) ──────────────────────────────────────────
    "org/gnome/settings-daemon/plugins/power" = {
      # Never sleep on AC (docked / dev machine); suspend on battery after
      # 30 minutes.
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-ac-timeout = 0;
      sleep-inactive-battery-type = "suspend";
      sleep-inactive-battery-timeout = 1800;
      # Power button prompts (default interactive); lid-close: ignore on AC
      # (external monitor workflow), suspend on battery.
      power-button-action = "interactive";
      lid-close-ac-action = "nothing";
      lid-close-battery-action = "suspend";
    };

    # ── Gruvbox wallpaper (matches desktop/login/gdm.nix) ──────────────
    "org/gnome/desktop/background" = {
      picture-uri = "file://${../../wallpapers/default.jpg}";
      picture-uri-dark = "file://${../../wallpapers/default.jpg}";
      primary-color = "#282828";
      color-shading-type = "solid";
    };

    "org/gnome/desktop/screensaver" = {
      picture-uri = "file://${../../wallpapers/lockscreen.jpg}";
      color-shading-type = "solid";
      primary-color = "#282828";
    };

    # ── Accessibility (left-sided hemiplegia) ──────────────────────────
    # Keep the universal-access indicator visible in quick settings so the
    # assistive features stay one click away.
    "org/gnome/desktop/a11y" = {
      always-show-universal-access-status = true;
    };
    # On-screen keyboard for pointer-driven input.
    "org/gnome/desktop/a11y/applications" = {
      screen-keyboard-enabled = true;
    };
    # Sticky keys: press-and-release modifiers instead of holding them
    # (single-handed shortcuts). Note the schema key spelling has no hyphen.
    "org/gnome/desktop/a11y/keyboard" = {
      stickykeys-enable = true;
    };
  };
}
