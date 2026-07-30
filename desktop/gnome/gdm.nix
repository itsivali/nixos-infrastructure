##############################################################################
#
# Desktop GNOME GDM
#
# Purpose
# -------
# Configures the GNOME Display Manager (GDM) with dark theme, cursor, and
# background settings applied to the login screen.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Enable GDM with auto-suspend disabled
# - Install theme/cursor/icon packages for the GDM user profile
# - Configure GDM dconf database with dark GTK theme, cursor, and background
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
  theme = import ../../home/hyprland/themes;
in
{
  config = lib.mkIf cfg.enable {
    services.displayManager.gdm = {
      enable = true;
      autoSuspend = false;
    };

    # GDM runs as the 'gdm' user and only sees system packages, so the
    # cursor/icon/GTK theme packages must live in the system profile.
    environment.systemPackages = [
      pkgs.bibata-cursors
      pkgs.tela-icon-theme
      pkgs.adw-gtk3
    ];

    programs.dconf.profiles.gdm.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          gtk-theme = theme.gtk.theme;
          color-scheme = "prefer-dark";
          icon-theme = theme.gtk.iconTheme;
          cursor-theme = theme.gtk.cursorTheme;
          cursor-size = lib.gvariant.mkInt32 24;
          font-name = "${theme.fonts.sans} ${builtins.toString theme.fonts.size}";
        };

        "org/gnome/desktop/background" = {
          picture-options = "zoom";
          primary-color = theme.colors.bg;
        };

        "org/gnome/desktop/screensaver" = {
          primary-color = theme.colors.bg;
        };
      };
    }];
  };
}
