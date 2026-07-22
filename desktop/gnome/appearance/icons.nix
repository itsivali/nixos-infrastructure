##############################################################################
#
# Desktop GNOME Appearance Icons
#
# Purpose
# -------
# Installs the Tela icon theme for the GNOME desktop.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Install tela-icon-theme system package
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tela-icon-theme ];
  };
}
