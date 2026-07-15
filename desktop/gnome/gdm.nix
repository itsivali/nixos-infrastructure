{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    services.displayManager.gdm = {
      enable = true;
      autoSuspend = false;
    };

    programs.dconf.profiles.gdm.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          gtk-theme = "adw-gtk3-dark";
          color-scheme = "prefer-dark";
          icon-theme = "Tela-dark";
          cursor-theme = "Bibata-Modern-Ice";
          cursor-size = lib.gvariant.mkInt32 24;
          font-name = "Inter 11";
        };

        "org/gnome/desktop/background" = {
          picture-options = "zoom";
          primary-color = "#282828";
        };

        "org/gnome/desktop/screensaver" = {
          primary-color = "#282828";
        };
      };
    }];
  };
}
