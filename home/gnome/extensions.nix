##############################################################################
#
# Home Manager — GNOME Shell Extensions
#
# Purpose
# -------
# Configure the curated GNOME Shell extensions via dconf settings.
# Extensions are installed by desktop/gnome/extensions.nix; this
# module owns their declarative behavior.
#
# Ownership
# ---------
# org.gnome.shell.extensions.* (dconf)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  extensions = with pkgs.gnomeExtensions; [
    dash-to-dock
    just-perfection
    caffeine
    clipboard-indicator
    vitals
  ];
in
{
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = map (extension: extension.extensionUuid) extensions;
      disable-user-enabled-extensions = false;
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      extend-height = false;
      dock-fixed = false;
      transparency-mode = "DYNAMIC";
      background-opacity = lib.gvariant.mkDouble 0.8;
      dash-max-icon-size = lib.gvariant.mkInt32 40;
      click-action = "previews";
      animate-show-apps = false;
      animate-windows = false;
      show-favorites = true;
      show-trash = false;
      multi-monitor = true;
    };

    "org/gnome/shell/extensions/just-perfection" = {
      panel-in-overview = true;
      dash = true;
      workspace = true;
      workspace-popup = true;
      search = true;
      type-to-search = true;
      theme = true;
      app-menu = true;
      app-menu-icon = true;
      aggregate-menu = true;
    };

    "org/gnome/shell/extensions/caffeine" = {
      enable-and-show-notifications = true;
      show-indicator = "always";
    };

    "org/gnome/shell/extensions/clipboard-indicator" = {
      history-size = lib.gvariant.mkInt32 10;
      display-mode = "both";
      show-copy-notification = false;
      paste-on-select = false;
      enable-keybindings = true;
      toggle-menu = [ "<Super>v" ];
    };

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
      hide-system-monitor = true;
    };
  };
}
