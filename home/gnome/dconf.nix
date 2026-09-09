##############################################################################
#
# Home — GNOME Shell dconf Configuration
#
# Purpose
# -------
# Declarative GNOME Shell configuration via dconf. Owns workspaces, keyboard
# shortcuts, favorite applications, appearance, power management, lock screen,
# notifications, and GNOME Console theming. Every value is sourced from the
# Gruvbox design system where applicable.
#
# Ownership
# ---------
# dconf.settings."org/gnome/*"
#
# Notes
# -----
# GVariant types are mandatory for non-string keys (nixpkgs #307965).
# Use lib.hm.gvariant.mkInt32, mkUint32, mkDouble, etc.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox;
  wallpaper = builtins.toString ../../wallpapers/default.jpg;
  lockscreen = builtins.toString ../../wallpapers/lockscreen.jpg;
in
{
  dconf.settings = {
    # ── Workspaces ──────────────────────────────────────────────────────
    # Static 10-workspace layout with the historical workspace names.
    "org/gnome/mutter" = {
      dynamic-workspaces = false;
    };

    "org/gnome/desktop/wm/preferences" = {
      num-workspaces = lib.hm.gvariant.mkInt32 10;
      workspace-names = [
        "α Web"
        "β Term"
        "γ Code"
        "δ Docs"
        "ε Files"
        "ζ Mail"
        "η Comm"
        "θ Media"
        "ι Sys"
        "κ Misc"
      ];
    };

    # ── Window Manager Keybindings ───────────────────────────────────────
    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      switch-to-workspace-5 = [ "<Super>5" ];
      switch-to-workspace-6 = [ "<Super>6" ];
      switch-to-workspace-7 = [ "<Super>7" ];
      switch-to-workspace-8 = [ "<Super>8" ];
      switch-to-workspace-9 = [ "<Super>9" ];
      switch-to-workspace-10 = [ "<Super>0" ];

      move-to-workspace-1 = [ "<Shift><Super>1" ];
      move-to-workspace-2 = [ "<Shift><Super>2" ];
      move-to-workspace-3 = [ "<Shift><Super>3" ];
      move-to-workspace-4 = [ "<Shift><Super>4" ];
      move-to-workspace-5 = [ "<Shift><Super>5" ];
      move-to-workspace-6 = [ "<Shift><Super>6" ];
      move-to-workspace-7 = [ "<Shift><Super>7" ];
      move-to-workspace-8 = [ "<Shift><Super>8" ];
      move-to-workspace-9 = [ "<Shift><Super>9" ];
      move-to-workspace-10 = [ "<Shift><Super>0" ];

      toggle-maximized = [ "<Super>m" ];
      minimize = [ "<Super>comma" ];
      close = [ "<Super>q" ];
      show-desktop = [ "<Super>d" ];
    };

    # ── Shell Keybindings ────────────────────────────────────────────────
    "org/gnome/shell/keybindings" = {
      toggle-overview = [ "<Super>" ];
      toggle-application-view = [ "<Super>a" ];
    };

    # ── Favorite Applications ────────────────────────────────────────────
    "org/gnome/shell" = {
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Console.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.TextEditor.desktop"
        "org.gnome.Settings.desktop"
        "org.gnome.Evince.desktop"
      ];
    };

    # ── Appearance ───────────────────────────────────────────────────────
    "org/gnome/desktop/background" = {
      picture-uri = "file://${wallpaper}";
      picture-uri-dark = "file://${wallpaper}";
      primary-color = theme.colors.bg;
      picture-options = "zoom";
    };

    "org/gnome/desktop/screensaver" = {
      picture-uri = "file://${lockscreen}";
      primary-color = theme.colors.bg;
      picture-options = "zoom";
      lock-enabled = true;
      lock-delay = lib.hm.gvariant.mkUint32 300;
    };

    # ── Interface (supplements home/theming.nix) ─────────────────────────
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "orange";
      font-antialiasing = "rgba";
      font-hinting = "full";
      cursor-size = theme.gtk.cursorSize;
    };

    # ── Power Management ─────────────────────────────────────────────────
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-battery-type = "nothing";
      power-button-action = "interactive";
      idle-dim = false;
    };

    # ── Notifications ────────────────────────────────────────────────────
    "org/gnome/desktop/notifications" = {
      show-banners = true;
      show-in-lock-screen = false;
    };

    "org/gnome/desktop/notifications/application/firefox" = {
      enable = true;
    };

    # ── GNOME Console (kgx) ─────────────────────────────────────────────
    # Console has a flat dconf schema with no profile support.
    # Theme = "night" gives dark mode; custom font overrides system default.
    "org/gnome/Console" = {
      theme = "night";
      use-system-font = false;
      custom-font = "${theme.terminal.font} ${toString theme.terminal.fontSize}";
      ignore-scrollback-limit = true;
      transparency = false;
    };

    # ── File Manager (Nautilus) ──────────────────────────────────────────
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
      show-hidden-files = false;
      show-directory-item-counts = "always";
    };

    "org/gnome/nautilus/list-view" = {
      use-default-columns = true;
      default-visible-columns = [
        "name"
        "size"
        "date-modified"
        "mime-type"
      ];
    };
  };
}
