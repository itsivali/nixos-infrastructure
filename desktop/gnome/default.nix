##############################################################################
#
# Desktop — GNOME
#
# Purpose
# -------
# GNOME desktop environment module. Barrel that wires the GNOME session, the
# curated application stack, system services and GNOME Shell extensions
# together, gated on ivali.desktop.gnome.enable.
#
# Ownership
# ---------
# ivali.desktop.gnome
#
# Responsibilities
# ----------------
# - Declare ivali.desktop.gnome.enable
# - Import the GNOME session + application stack (session.nix)
# - Import the curated GNOME Shell extension set (extensions.nix)
# - Login manager + login-screen theming live in desktop/login/gdm.nix
# - Audio / portals / environment live in desktop/common/*
#
##############################################################################

{ config, lib, ... }:

{
  imports = [
    ./session.nix
    ./extensions.nix
  ];

  options.ivali.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment with curated Gruvbox-theming";
  };

  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    # Any active desktop environment activates the shared platform gate so
    # common/{audio,portals,environment} follow the active desktop rather
    # than being coupled to any single environment's flag.
    ivali.desktop.enable = true;
  };
}
