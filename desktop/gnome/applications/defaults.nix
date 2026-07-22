##############################################################################
#
# Desktop GNOME Applications Defaults
#
# Purpose
# -------
# Configures GNOME default application preferences for terminal, browser,
# and file manager via dconf.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Set default terminal to gnome-console
# - Set default browser to firefox
# - Set default file manager to nautilus
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
        "org/gnome/desktop/applications/terminal" = {
          exec = "gnome-console";
          exec-arg = "-e";
        };

        "org/gnome/desktop/applications/browser" = {
          exec = "firefox";
        };

        "org/gnome/desktop/applications/file-manager" = {
          exec = "nautilus";
        };
      };
    }];
  };
}
