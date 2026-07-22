##############################################################################
#
# Desktop GNOME Appearance GTK
#
# Purpose
# -------
# Installs GTK themes (adw-gtk3, gnome-themes-extra) for the GNOME desktop.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Install adw-gtk3 and gnome-themes-extra system packages
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      adw-gtk3
      gnome-themes-extra
    ];
  };
}
