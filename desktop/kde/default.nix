##############################################################################
#
# Desktop — KDE Plasma 6
#
# Purpose
# -------
# System-level KDE Plasma 6 desktop enablement. Barrel that wires the KDE
# Wayland session (plasma6 + SDDM), the KDE application stack, remote
# desktop, and shared desktop infrastructure together, gated on
# ivali.desktop.kde.enable.
#
# Ownership
# ---------
# ivali.desktop.kde
#
# Responsibilities
# ----------------
# - Declare ivali.desktop.kde.enable
# - Activate the generic ivali.desktop platform gate so the shared audio,
#   portals and environment foundation applies to KDE
# - Import the KDE session (session.nix), shortcuts (shortcuts.nix),
#   remote desktop (remote-desktop.nix), and keyboard config
# - Login manager lives in desktop/login/sddm.nix
# - Audio / portals / environment live in desktop/common/*
#
##############################################################################

{ config, lib, ... }:

{
  imports = [
    ./session.nix
    ./remote-desktop.nix
    ./keyboard.nix
  ];

  options.ivali.desktop.kde = {
    enable = lib.mkEnableOption "KDE Plasma 6 desktop environment with Mokka theming";
  };

  config = lib.mkIf (config.ivali.desktop.kde.enable or false) {
    # Every active desktop environment activates the shared platform gate;
    # common/{audio,portals,environment} respond to this rather than to the
    # per-environment flag, so switching environments cannot silently drop
    # the shared desktop foundation.
    ivali.desktop.enable = true;
  };
}
