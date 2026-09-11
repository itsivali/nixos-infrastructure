##############################################################################
#
# Home — GNOME Shell Extensions
#
# Purpose
# -------
# Install and configure GNOME Shell extensions. Each extension must earn its
# place: GNOME natively provides most functionality, so extensions are used
# only where they add genuine value beyond what GNOME offers.
#
# Ownership
# ---------
# home.packages, dconf.settings."org/gnome/shell"
#
# Extensions
# ----------
# - ArcMenu: traditional application menu (Zorin-like UX) — user-managed
# - Blur my Shell: subtle visual depth on overview background
# - Caffeine: temporary keep-awake toggle
# - Clipboard Indicator: Wayland-compatible clipboard history
# - Dash to Dock: persistent bottom dock for quick application access
# - Just Perfection: top bar refinement, panel customization
# - No Overview on Startup: boot into desktop, not the overview
# - Rounded Window Corners Reborn: consistent corner radii
# - Search Light: Spotlight-like fuzzy search (Super+Space)
# - Vitals: compact system resource monitoring in top bar
# - AppIndicator/KStatusNotifierItem: legacy system tray support
#
# NOTE: Alphabetical App Grid was removed. ArcMenu is the canonical
# application browser (see AGENTS.md / IVALi Desktop spec); the GNOME
# application grid is intentionally de-emphasized.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    gnomeExtensions.arcmenu
    gnomeExtensions.blur-my-shell
    gnomeExtensions.caffeine
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.dash-to-dock
    gnomeExtensions.just-perfection
    gnomeExtensions.no-overview
    gnomeExtensions.rounded-window-corners-reborn
    gnomeExtensions.search-light
    gnomeExtensions.vitals
    gnomeExtensions.appindicator
  ];

  dconf.settings = {
    # ── Enable extensions ────────────────────────────────────────────────
    "org/gnome/shell" = {
      enabled-extensions = [
        pkgs.gnomeExtensions.arcmenu.extensionUuid
        pkgs.gnomeExtensions.blur-my-shell.extensionUuid
        pkgs.gnomeExtensions.caffeine.extensionUuid
        pkgs.gnomeExtensions.clipboard-indicator.extensionUuid
        pkgs.gnomeExtensions.dash-to-dock.extensionUuid
        pkgs.gnomeExtensions.just-perfection.extensionUuid
        pkgs.gnomeExtensions.no-overview.extensionUuid
        pkgs.gnomeExtensions.rounded-window-corners-reborn.extensionUuid
        pkgs.gnomeExtensions.search-light.extensionUuid
        pkgs.gnomeExtensions.vitals.extensionUuid
        pkgs.gnomeExtensions.appindicator.extensionUuid
      ];
    };

    # ── ArcMenu ──────────────────────────────────────────────────────────
    # User-managed via the GNOME Extensions app. Declarative dconf would
    # overwrite layout/look/pinned-apps customizations on every rebuild,
    # so ArcMenu's settings are intentionally NOT managed here. ArcMenu
    # remains the PRIMARY graphical application browser (IVALi Desktop
    # spec).
    #
    # ── Blur my Shell ────────────────────────────────────────────────────
    # Subtle blur on the overview background only. NOT applied to the
    # panel, dash-to-dock, or application windows.
    "org/gnome/shell/extensions/blur-my-shell" = {
      sigma = lib.hm.gvariant.mkInt32 30;
      brightness = lib.hm.gvariant.mkDouble 0.85;
    };

    "org/gnome/shell/extensions/blur-my-shell/panel" = {
      enable = false;
    };

    "org/gnome/shell/extensions/blur-my-shell/appfolder" = {
      enable = false;
    };

    "org/gnome/shell/extensions/blur-my-shell/overview" = {
      enable = true;
    };

    "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
      enable = false;
    };

    "org/gnome/shell/extensions/blur-my-shell/window-list" = {
      enable = false;
    };

    # ── Caffeine ─────────────────────────────────────────────────────────
    # Temporary keep-awake toggle. Normal GNOME power management remains
    # intact when Caffeine is off. Useful for long builds, presentations,
    # downloads, and extended work sessions.
    "org/gnome/shell/extensions/caffeine" = {
      enable-and-show-notifications = true;
      show-indicator = "always";
    };

    # ── Clipboard Indicator ──────────────────────────────────────────────
    "org/gnome/shell/extensions/clipboard-indicator" = {
      history-size = lib.hm.gvariant.mkInt32 100;
      display-mode = "both";
      show-copy-notification = false;
      paste-on-select = false;
      enable-keybindings = true;
      toggle-menu = [ "<Super>v" ];
    };

    # ── Dash to Dock ─────────────────────────────────────────────────────
    # Floating bottom dock that visually disappears into the wallpaper.
    # FIXED transparency mode with zero background opacity: no opaque or
    # semi-opaque panel, no visible background rectangle. Only the icons,
    # running indicators, focus state, and a subtle hover stay visible.
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      extend-height = false;
      transparency-mode = "FIXED";
      background-opacity = lib.hm.gvariant.mkDouble 0.0;
      height-fraction = lib.hm.gvariant.mkDouble 0.85;
      dash-max-icon-size = lib.hm.gvariant.mkInt32 40;
      click-action = "previews";
      middle-click-action = "launch";
      shift-click-action = "launch";
      scroll-action = "switch-workspace";
      isolate-workspaces = false;
      isolate-monitors = false;
      show-show-apps-button = false;
      multi-monitor = true;
      intellihide = true;
      intellihide-mode = "ALL_WINDOWS";
      autohide = true;
      autohide-in-fullscreen = true;
      running-indicator-style = "DOTS";
      force-straight-corner = false;
      show-windows-preview = true;
      show-trash = false;
      custom-theme-shrink = false;
      dock-fixed = false;
    };

    # ── Just Perfection ──────────────────────────────────────────────────
    # Panel refinement only. Animations restored to default for smooth
    # desktop feel. ArcMenu replaces the app menu; Just Perfection
    # configures the overview dash and workspace behavior. The application
    # grid is de-emphasized — ArcMenu is the canonical launcher.
    "org/gnome/shell/extensions/just-perfection" = {
      panel-size = 28;
      panel-in-overview = true;
      top-panel-position = "top";
      clock-menu-position = "right";
      dash = true;
      dash-icon-size = lib.hm.gvariant.mkInt32 48;
      dash-separator = lib.hm.gvariant.mkInt32 0;
      workspace = true;
      workspace-popup = true;
      workspace-switcher-should-show = true;
      workspace-wrap-around = true;
      hot-corner = true;
      search = true;
      type-to-search = true;
      double-super-to-appgrid = false;
      theme = true;
      ripple-box = false;
      window-demands-attention-focus = true;
      window-picker-icon = true;
      window-preview-caption = false;
      window-preview-close-button = true;
      animation = lib.hm.gvariant.mkInt32 (-1);
      startup-status = lib.hm.gvariant.mkInt32 0;
      app-menu = false;
      app-menu-icon = false;
      aggregate-menu = true;
      keyboard-layout = true;
      events-button = true;
      osd = true;
      osd-position = lib.hm.gvariant.mkInt32 0;
      notification-banner-position = lib.hm.gvariant.mkInt32 0;
      background-menu = true;
      calendar = true;
      world-clock = false;
      weather = false;
      power-icon = true;
      show-apps-button = false;
      activities-button = true;
      activities-button-label = false;
      gesture = true;
      looking-glass-height = lib.hm.gvariant.mkInt32 400;
      looking-glass-width = lib.hm.gvariant.mkInt32 600;
      workspace-background-corner-size = lib.hm.gvariant.mkInt32 0;
    };

    # ── Rounded Window Corners Reborn ────────────────────────────────────
    # Consistent corner radii across all windows. Skips maximized and
    # fullscreen windows for correct behavior.
    "org/gnome/shell/extensions/rounded-window-corners-reborn" = {
      border-radius = lib.hm.gvariant.mkUint32 12;
      skip-maximized = true;
      skip-taskbars = true;
    };

    # ── Vitals ───────────────────────────────────────────────────────────
    # Compact system monitoring in the top bar. Shows only the essential
    # metrics: CPU, memory, temperature, and network. Disk, GPU, and fan
    # are hidden to keep the top bar clean.
    "org/gnome/shell/extensions/vitals" = {
      position-in-panel = "right";
      show-cpu = true;
      show-memory = true;
      show-temperature = true;
      show-network = true;
      show-disk = false;
      show-gpu = false;
      show-fan = false;
      use-fahrenheit = false;
      alphabetical-order = false;
      time-stamp = "%R";
      hide-system-monitor = true;
    };
  };
}
