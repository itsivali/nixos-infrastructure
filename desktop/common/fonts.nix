##############################################################################
#
# Desktop — Common Fonts
#
# Purpose
# -------
# System-level font configuration: enable fontconfig plus Inter (sans) and
# MesloLGS (monospace) for terminals and the console.
#
# Ownership
# ---------
# fonts, console
#
##############################################################################

{ pkgs, ... }:

{
  fonts.fontconfig.enable = true;

  # Inter for UI, MesloLGS Nerd Font for the console
  fonts.packages = with pkgs; [
    inter
    nerd-fonts.meslo-lg
  ];

  console = {
    font = "Lat2-Terminus16";
    packages = [ pkgs.terminus_font ];
  };
}
