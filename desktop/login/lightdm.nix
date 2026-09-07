##############################################################################
#
# Desktop — Login (LightDM)
#
# Purpose
# -------
# LightDM login manager for the XFCE desktop. Replaces GDM (GNOME's own
# display manager, whose Wayland-only greeter is a poor fit for the
# lightweight XFCE build). Runs the GTK greeter with the Gruvbox wallpaper
# and themes the login screen to the IVΛLI visual identity.
#
# Ownership
# ---------
# services.displayManager.lightdm
#
# Responsibilities
# ----------------
# - Present the LightDM GTK greeter on the X11 session
# - Launch the XFCE session by default (defaultSession = "xfce")
# - Theme the login screen: Gruvbox wallpaper, dark theme, Tela-dark icons,
#   Bibata cursor (28px, accessibility)
#
# Notes
# -----
# - LightDM asserts services.xserver.enable is set; the XFCE session module
#   (desktop/xfce/session.nix) sets it.
# - The greeter uses GTK theming (adw-gtk3-dark) + the same Gruvbox wallpaper
#   as the XFCE desktop so login and desktop are visually continuous.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox;
  wallpaper = ../../wallpapers/default.jpg;
in
{
  config = lib.mkIf (config.ivali.desktop.enable or false) {
    services.xserver.displayManager.lightdm = {
      enable = true;

      greeters.gtk = {
        enable = true;

        theme = {
          package = pkgs.adw-gtk3;
          name = theme.gtk.theme;
        };

        iconTheme = {
          package = pkgs.tela-icon-theme;
          name = theme.gtk.iconTheme;
        };

        cursorTheme = {
          package = pkgs.bibata-cursors;
          name = theme.gtk.cursorTheme;
          size = theme.gtk.cursorSize;
        };

        # 24h clock in the greeter, matching the desktop panel.
        clock-format = "%H:%M";

        indicators = [
          "~host"
          "~spacer"
          "~clock"
          "~spacer"
          "~session"
          "~power"
        ];

        extraConfig = ''
          background = ${wallpaper}
          user-background = false
          font-name = ${theme.fonts.sans} ${toString theme.fonts.size}
          xft-antialias = true
          xft-hintstyle = hintfull
        '';
      };
    };

    # Boot straight into the XFCE session.
    services.displayManager.defaultSession = "xfce";
  };
}
