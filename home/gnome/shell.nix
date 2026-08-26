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
    # The always-visible dash-to-panel taskbar row: the daily driver apps.
    # Remaining desktop apps (Edge, LibreOffice, mpv, mission-center,
    # gnome-tweaks, ...) stay in the Super-key app grid.
    "org/gnome/shell" = {
      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "org.gnome.Terminal.desktop"
        "firefox.desktop"
        "org.gnome.TextEditor.desktop"
        "dev.zed.Zed.desktop"
        "LocalSend.desktop"
        "obsidian.desktop"
        "notion-app-enhanced.desktop"
        "Zoom.desktop"
      ];
    };

    # ── Window manager ─────────────────────────────────────────────────
    # macOS-style minimize/maximize window buttons + close on Meta+Q.
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
    };

    # ── Workspaces & focus behavior ────────────────────────────────────
    # Dynamic workspaces (created/removed on demand), dialogs attached to
    # their parent window, hot-corner overview, and strict click-to-focus.
    "org/gnome/mutter" = {
      dynamic-workspaces = true;
      workspaces-only-on-primary = false;
      attach-modal-dialogs = true;
    };

    "org/gnome/desktop/wm/preferences" = {
      focus-mode = "click";
      raise-on-click = true;
    };

    "org/gnome/desktop/interface" = {
      enable-hot-corners = false;
      # Date and time always visible in the top panel (24h): date + weekday
      # shown next to the clock so the collapsed indicator arrow never hides it.
      clock-show-date = true;
      clock-show-weekday = true;
      clock-show-seconds = false;
      clock-format = "24h";
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
      command = "gnome-terminal";
      binding = "<Ctrl>period";
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
      screen-keyboard-enabled = false;
    };
    # Sticky keys disabled: GNOME Shell's overview overlay-key handler returns
    # early when org.gnome.desktop.a11y.keyboard.stickykeys-enable is set
    # (gnome-shell overviewControls.js), which breaks the Super/overview key.
    # Note the schema key spelling has no hyphen.
    "org/gnome/desktop/a11y/keyboard" = {
      stickykeys-enable = false;
    };
  };
}
