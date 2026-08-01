##############################################################################
#
# Desktop — Hyprland
#
# Purpose
# -------
# Hyprland desktop environment module. Barrel that wires the compositor and
# system packages together, gated on ivali.desktop.hyprland.enable.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Declare ivali.desktop.hyprland.enable
# - Import compositor + system packages
# - Portal integration lives in desktop/common/portals.nix
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.hyprland;
in
{
  imports = [
    ./compositor.nix
    ./packages.nix
  ];

  options.ivali.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop environment with themed components";
  };
}
