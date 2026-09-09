##############################################################################
#
# Desktop — GNOME
#
# Purpose
# -------
# GNOME desktop environment module. Barrel that wires the GNOME Wayland
# session, the modern GNOME application stack, and the shared desktop
# infrastructure together, gated on ivali.desktop.gnome.enable.
#
# Ownership
# ---------
# ivali.desktop.gnome
#
# Responsibilities
# ----------------
# - Declare ivali.desktop.gnome.enable
# - Activate the generic ivali.desktop platform gate so the shared audio,
#   portals and environment foundation applies to GNOME
# - Import the GNOME session + application stack (session.nix)
# - Login manager lives in desktop/login/gdm.nix
# - Audio / portals / environment live in desktop/common/*
#
##############################################################################

{ config, lib, ... }:

{
  imports = [
    ./session.nix
  ];

  options.ivali.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment with Gruvbox theming";
  };

  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    # Every active desktop environment activates the shared platform gate;
    # common/{audio,portals,environment} respond to this rather than to the
    # per-environment flag, so switching environments cannot silently drop
    # the shared desktop foundation.
    ivali.desktop.enable = true;
  };
}
