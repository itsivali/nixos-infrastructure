{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/gtk-3.0" = {
        source = "${hc}/Configs/.config/gtk-3.0";
        recursive = true;
        force = true;
        mutable = true;
      };

      ".config/gtk-4.0" = {
        source = "${hc}/Configs/.config/gtk-4.0";
        recursive = true;
        force = true;
        mutable = true;
      };
    };

    gtk = {
      enable = true;
      font.name = "MesloLGS Nerd Font 10";
      theme = {
        name = "Wallbash-Gtk";
        package = hyde-configs;
      };
      iconTheme = {
        name = "Tela-circle-dracula";
        package = pkgs.tela-circle-icon-theme;
      };
      cursorTheme = {
        name = "Bibata-Modern-Ice";
        package = pkgs.bibata-cursors;
        size = 24;
      };
    };
  };
}
