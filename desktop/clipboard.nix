##############################################################################
#
# Wayland Clipboard
#
# Purpose
# -------
# Dedicated Wayland clipboard module. Provides wl-clipboard (wl-copy,
# wl-paste) system-wide. Decoupled from Bitwarden so clipboard tools
# are always available regardless of whether Bitwarden is enabled.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Install wl-clipboard system-wide
# - Ensure clipboard works across terminal, GNOME, browser, SSH (where
#   Wayland display is available)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.clipboard;
in
{
  options.ivali.desktop.clipboard = {
    enable = lib.mkEnableOption "Wayland clipboard integration (wl-clipboard)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wl-clipboard
    ];
  };
}
