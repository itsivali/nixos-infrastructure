{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      swww
    ];

    home.file = {
      ".config/swww" = {
        source = "${hc}/Configs/.config/swww";
        recursive = true;
      };
    };
  };
}
