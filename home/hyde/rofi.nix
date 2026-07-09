{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/rofi" = {
        source = "${hc}/Configs/.config/rofi";
        recursive = true;
        force = true;
        mutable = true;
      };
    };
  };
}
