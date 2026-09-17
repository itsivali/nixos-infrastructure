##############################################################################
#
# Desktop — GNOME
#
# Purpose
# -------
# System-level GNOME Shell desktop enablement. Barrel that wires the GNOME
# Wayland session (GNOME Shell + Mutter + GDM), the GNOME application stack,
# remote desktop, extensions, and shared desktop infrastructure together,
# gated on ivali.desktop.gnome.enable.
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
# - Import the GNOME session (session.nix), extensions.nix, and
#   remote-desktop.nix
# - Login manager lives in desktop/login/gdm.nix
# - Audio / portals / environment live in desktop/common/*
#
##############################################################################

{ config, lib, ... }:

{
  imports = [
    ./session.nix
    ./extensions.nix
    ./remote-desktop.nix
  ];

  options.ivali.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment with Mokka theming";
  };

  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    # Every active desktop environment activates the shared platform gate;
    # common/{audio,portals,environment} respond to this rather than to the
    # per-environment flag, so switching environments cannot silently drop
    # the shared desktop foundation.
    ivali.desktop.enable = true;
  };
}
