{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    fonts = {
      packages = with pkgs; [
        inter
        cantarell-fonts
        jetbrains-mono
        liberation_ttf
      ];

      fontconfig = {
        enable = true;
        defaultFonts = {
          sansSerif = [ "Inter" "Cantarell" ];
          serif = [ "Liberation Serif" ];
          monospace = [ "JetBrains Mono" ];
        };
      };
    };
  };
}
