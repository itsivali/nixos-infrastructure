{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/waybar" = {
        source = "${hc}/Configs/.config/waybar";
        recursive = true;
        force = true;
        mutable = true;
      };
    };
  };
}
