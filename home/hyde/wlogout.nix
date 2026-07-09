{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/wlogout" = {
        source = "${hc}/Configs/.config/wlogout";
        recursive = true;
        force = true;
        mutable = true;
      };
    };
  };
}
