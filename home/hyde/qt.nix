{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    qt = {
      enable = true;
      platformTheme = "gtk2";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };
  };
}
