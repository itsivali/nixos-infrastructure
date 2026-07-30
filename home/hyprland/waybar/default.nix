##############################################################################
#
# Home — Waybar Desktop Module
#
# Purpose
# -------
# Waybar status bar Home Manager module. Imports modular JSON config and theme CSS.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes;
  waybarConfig = import ./config.nix;
  waybarStyle = import ./style.nix { inherit theme; };
in
{
  programs.waybar = {
    enable = true;
    settings = waybarConfig;
    style = waybarStyle;
  };
}
