{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/hyde/themes" = {
        source = "${hc}/Configs/.config/hyde/themes";
        recursive = true;
        force = true;
        mutable = true;
      };

      ".local/share/hyde/themes" = {
        source = "${hc}/Configs/.local/share/hyde/themes";
        recursive = true;
        force = true;
        mutable = true;
      };
    };
  };
}
