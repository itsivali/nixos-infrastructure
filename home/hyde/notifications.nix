{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      dunst
      libnotify
    ];

    home.file = {
      ".config/dunst" = {
        source = "${hc}/Configs/.config/dunst";
        recursive = true;
        force = true;
        mutable = true;
      };
    };

    services.dunst = {
      enable = true;
      settings = {
        global = {
          monitor = 0;
          follow = "mouse";
          width = 300;
          height = 300;
          origin = "top-right";
          offset = "10x50";
          notification_limit = 20;
          progress_bar = true;
          indicate_hidden = "yes";
          transparency = 10;
          separator_height = 2;
          padding = 8;
          horizontal_padding = 8;
          text_icon_padding = 0;
          frame_width = 2;
          sort = "yes";
          font = "MesloLGS Nerd Font 10";
          markup = "full";
          format = "<b>%s</b>\\n%b";
          alignment = "left";
          show_age_threshold = 60;
          word_wrap = "yes";
          ellipsize = "middle";
          ignore_newline = "no";
          stack_duplicates = true;
          hide_duplicates_count = false;
          show_indicators = "yes";
        };
      };
    };
  };
}
