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
# - Clipboard Indicator: Wayland-compatible clipboard history
# - Just Perfection: top bar refinement, panel customization
# - Dash to Dock: persistent dock for quick application access
# - Forge: automatic tiling window management
# - System Monitor Next: system resource indicators in top bar
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.just-perfection
    gnomeExtensions.dash-to-dock
    gnomeExtensions.forge
    gnomeExtensions.system-monitor-next
  ];

  dconf.settings = {
    # ── Enable extensions ────────────────────────────────────────────────
    "org/gnome/shell" = {
      enabled-extensions = [
        pkgs.gnomeExtensions.clipboard-indicator.extensionUuid
        pkgs.gnomeExtensions.just-perfection.extensionUuid
        pkgs.gnomeExtensions.dash-to-dock.extensionUuid
        pkgs.gnomeExtensions.forge.extensionUuid
        pkgs.gnomeExtensions.system-monitor-next.extensionUuid
      ];
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

    # ── Just Perfection ──────────────────────────────────────────────────
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
      double-super-to-appgrid = true;
      theme = true;
      ripple-box = false;
      window-demands-attention-focus = true;
      window-picker-icon = true;
      window-preview-caption = false;
      window-preview-close-button = true;
      animation = lib.hm.gvariant.mkInt32 0;
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

    # ── Dash to Dock ─────────────────────────────────────────────────────
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "LEFT";
      extend-height = false;
      transparency-mode = "DYNAMIC";
      background-opacity = 0.8;
      height-fraction = lib.hm.gvariant.mkDouble 0.9;
      dash-max-icon-size = lib.hm.gvariant.mkInt32 48;
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
      running-indicator-style = "DEFAULT";
      force-straight-corner = false;
      show-windows-preview = true;
      show-trash = false;
    };

    # ── Forge (Tiling Window Manager) ───────────────────────────────────
    "org/gnome/shell/extensions/forge" = {
      focus-border-toggle = true;
      focus-border-size = lib.hm.gvariant.mkUint32 3;
      split-border-toggle = true;
      window-gap-size = lib.hm.gvariant.mkUint32 4;
      window-gap-hidden-on-single = true;
      resize-amount = lib.hm.gvariant.mkUint32 15;
      tiling-mode-enabled = true;
      quick-settings-enabled = true;
      stacked-tiling-mode-enabled = true;
      tabbed-tiling-mode-enabled = true;
      auto-split-enabled = true;
      preview-hint-enabled = true;
      showtab-decoration-enabled = true;
      move-pointer-focus-enabled = false;
      focus-on-hover-enabled = false;
      float-always-on-top-enabled = true;
      auto-exit-tabbed = true;
      dnd-center-layout = "tabbed";
    };

    "org/gnome/shell/extensions/forge/keybindings" = {
      focus-border-toggle = [ "<Super>x" ];
      window-gap-size-increase = [ "<Ctrl><Super>plus" ];
      window-gap-size-decrease = [ "<Ctrl><Super>minus" ];
      con-split-layout-toggle = [ "<Super>g" ];
      con-split-horizontal = [ "<Super>z" ];
      con-split-vertical = [ "<Super>v" ];
      con-stacked-layout-toggle = [ "<Shift><Super>s" ];
      con-tabbed-layout-toggle = [ "<Shift><Super>t" ];
      window-swap-left = [ "<Ctrl><Super>h" ];
      window-swap-down = [ "<Ctrl><Super>j" ];
      window-swap-up = [ "<Ctrl><Super>k" ];
      window-swap-right = [ "<Ctrl><Super>l" ];
      window-move-left = [ "<Shift><Super>h" ];
      window-move-down = [ "<Shift><Super>j" ];
      window-move-up = [ "<Shift><Super>k" ];
      window-move-right = [ "<Shift><Super>l" ];
      window-focus-left = [ "<Super>h" ];
      window-focus-down = [ "<Super>j" ];
      window-focus-up = [ "<Super>k" ];
      window-focus-right = [ "<Super>l" ];
      window-toggle-float = [ "<Super>c" ];
      window-toggle-always-float = [ "<Shift><Super>c" ];
      workspace-active-tile-toggle = [ "<Shift><Super>w" ];
      prefs-open = [ "<Super>Period" ];
      prefs-tiling-toggle = [ "<Super>w" ];
      window-swap-last-active = [ "<Super>Return" ];
    };

    # ── System Monitor Next ──────────────────────────────────────────────
    "org/gnome/shell/extensions/system-monitor-next" = {
      memory-show-text = true;
      memory-show-icon = true;
      cpu-show-text = true;
      cpu-show-icon = true;
      net-show-text = true;
      net-show-icon = true;
      disk-show-text = false;
      disk-show-icon = true;
      swap-show-text = false;
      swap-show-icon = false;
      gpu-show-text = false;
      gpu-show-icon = false;
      net-speed-unit = "bytes";
    };
  };
}
