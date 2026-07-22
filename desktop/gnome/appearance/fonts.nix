##############################################################################
#
# Desktop GNOME Appearance Fonts
#
# Purpose
# -------
# Installs and configures the GNOME font stack including Inter, Cantarell,
# JetBrains Mono, and Liberation, with fontconfig defaults.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Install system fonts (Inter, Cantarell, JetBrains Mono, Liberation)
# - Configure fontconfig default sans-serif, serif, and monospace families
#
##############################################################################

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
