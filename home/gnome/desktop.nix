##############################################################################
#
# Home Manager — GNOME Desktop Preferences
#
# Purpose
# -------
# GNOME desktop preferences via dconf settings. Drives the active GNOME
# session configuration: interface, window manager, shell extensions,
# session behavior, workspaces, and default applications.
#
# Only imported when ivali.desktop.gnome.enable = true (see home/default.nix).
#
# Ownership
# ---------
# dconf.settings
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  imports = [
    ./extensions.nix
  ];

  dconf.settings = {
    # ── Interface ────────────────────────────────────────────────
    # GNOME/Adwaita defaults for cursor, icons, and GTK theme.
    # color-scheme = prefer-dark makes Adwaita use its dark variant.
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "mauve";
      font-antialiasing = "rgba";
      font-hinting = "full";
    };

    # ── Window manager preferences ───────────────────────────────
    "org/gnome/desktop/wm/preferences" = {
      theme = "Adwaita-dark";
      button-layout = "appmenu:minimize,maximize,close";
      titlebar-font = "Inter Bold 10";
      document-font = "Inter 10";
      interface-font = "Inter 10";
      monospace-font = "MesloLGS NF 11";
    };

    # ── GNOME Shell ─────────────────────────────────────────────
    "org/gnome/shell" = {
      disable-user-enabled-extensions = false;
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Console.desktop"
        "LocalSend.desktop"
        "dev.zed.Zed.desktop"
        "writer.desktop"
        "notion-app-enhanced.desktop"
        "org.gnome.TextEditor.desktop"
        "org.gnome.gitlab.somas.Apostrophe.desktop"
        "obsidian.desktop"
        "Zoom.desktop"
      ];
    };

    # ── Session ─────────────────────────────────────────────────
    "org/gnome/desktop/session" = {
      idle-delay = 300;
      auto-save-session = false;
    };

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "suspend";
      power-button-action = "suspend";
    };

    # ── Lock screen ────────────────────────────────────────────
    "org/gnome/desktop/screensaver" = {
      lock-enabled = true;
      lock-delay = 0;
    };

    # ── Workspaces (dynamic) ────────────────────────────────────
    "org/gnome/mutter" = {
      dynamic-workspaces = true;
      edge-tiling = true;
    };

    # ── Window management keybindings ───────────────────────────
    "org/gnome/desktop/wm/keybindings" = {
      # Workspace navigation (keyboard-first)
      switch-to-workspace-left = [ "<Super>Page_Up" ];
      switch-to-workspace-right = [ "<Super>Page_Down" ];
      switch-to-workspace-up = [ "<Super>Home" ];
      switch-to-workspace-down = [ "<Super>End" ];
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];

      # Window management
      close = [ "<Super>Q" ];
      maximize = [ "<Super>M" ];
      toggle-fullscreen = [ "<Super>F" ];
      move-to-center = [ "<Super>C" ];

      # Move window between workspaces
      move-to-workspace-1 = [ "<Super><Shift>1" ];
      move-to-workspace-2 = [ "<Super><Shift>2" ];
      move-to-workspace-3 = [ "<Super><Shift>3" ];
      move-to-workspace-4 = [ "<Super><Shift>4" ];

      # Quick tiling (keyboard-first workflow)
      move-to-corner-nw = [ "<Super>H" ];
      move-to-corner-ne = [ "<Super>L" ];
      move-to-corner-sw = [ "<Super>K" ];
      move-to-corner-se = [ "<Super>J" ];

      # Overview / Activities
      toggle-overview = [ "Super" "<Super>Tab" ];
    };

    "org/gnome/shell/keybindings" = {
      # Launcher shortcuts
      launch-web = [ "<Super>B" ];
      launch-files = [ "<Super>E" ];
      launch-terminal = [ "<Super>T" ];

      # Screenshot
      screenshot = [ "<Print>" ];
      screenshot-window = [ "<Alt>Print" ];
      screenshot-area = [ "<Ctrl>Print" ];
    };
  };
}
