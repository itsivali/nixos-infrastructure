##############################################################################
#
# Desktop — XFCE
#
# Purpose
# -------
# XFCE desktop environment module. Barrel that wires the XFCE session, the
# lightweight GTK application stack, and the shared X11-based desktop
# infrastructure together, gated on ivali.desktop.xfce.enable.
#
# Ownership
# ---------
# ivali.desktop.xfce
#
# Responsibilities
# ----------------
# - Declare ivali.desktop.xfce.enable
# - Activate the generic ivali.desktop platform gate so the shared audio,
#   portals and environment foundation applies to XFCE
# - Import the XFCE session + lightweight application stack (session.nix)
# - Login manager lives in desktop/login/lightdm.nix
# - Audio / portals / environment live in desktop/common/*
#
##############################################################################

{ config, lib, ... }:

{
  imports = [
    ./session.nix
  ];

  options.ivali.desktop.xfce = {
    enable = lib.mkEnableOption "XFCE desktop environment with curated Gruvbox-theming";
  };

  config = lib.mkIf (config.ivali.desktop.xfce.enable or false) {
    # Every active desktop environment activates the shared platform gate;
    # common/{audio,portals,environment} respond to this rather than to the
    # per-environment flag, so switching environments cannot silently drop
    # the shared desktop foundation.
    ivali.desktop.enable = true;
  };
}
