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
