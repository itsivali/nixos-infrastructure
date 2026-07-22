##############################################################################
#
# Desktop GNOME Applications MIME
#
# Purpose
# -------
# Configures GNOME default applications for various MIME types and handlers
# via dconf settings.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Set terminal, browser, file manager, and office default applications
# - Define Evolution mail and Epiphany web stubs
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    programs.dconf.profiles.user.databases = [{
      settings = {
        "org/gnome/desktop/default-applications" = {
          terminal = "gnome-console";
          terminal-args = "";
          browser = "firefox";
          browser-args = "";
          filemanager = "nautilus";
          filemanager-args = "";
          office = "libreoffice";
        };

        "org/gnome/evolution/mail" = { };
        "org/gnome/epiphany/web" = { };
      };
    }];
  };
}
