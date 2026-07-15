{ config, lib, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
    };
  };
}
