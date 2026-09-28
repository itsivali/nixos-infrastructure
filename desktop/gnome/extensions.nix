##############################################################################
#
# Desktop — GNOME Extensions
#
# Purpose
# -------
# Install the curated GNOME Shell extensions used by the polished
# GNOME workstation. Declarative extension configuration lives in
# home/gnome/extensions.nix (dconf settings are a user-level
# concern, not a system-level one).
#
# Ownership
# ---------
# environment.systemPackages
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  extensions = with pkgs.gnomeExtensions; [
    dash-to-dock
    just-perfection
    caffeine
    clipboard-indicator
    vitals
    tiling-assistant
    gsconnect
  ];
in
{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    environment.systemPackages = extensions;
  };
}
