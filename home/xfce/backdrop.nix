##############################################################################
#
# Home — XFCE Desktop Backdrop
#
# Purpose
# -------
# XFCE desktop backdrop: solid Gruvbox background (no wallpaper image) with
# desktop icons disabled. Colors are sourced from theme/gruvbox so they cannot
# drift from the rest of the design system.
#
# Ownership
# ---------
# xfce4-desktop (xfconf channel)
#
# Does NOT Own
# ------------
# - Panel / window manager / shortcuts (panel.nix)
# - Power management (power.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox;
  c = theme.colors;
in
{
  # Backdrop preferences are applied through a small setup script that runs
  # once at login (same pattern as the panel module).
  home.file.".config/xfce4/xfce4-desktop-setup.sh" = {
    executable = true;
    text = ''
      set -euo pipefail

      # ── Desktop ────────────────────────────────────────────────────────────
      xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-style --create --type int --set 5
      xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/color1 --create --type string --set "${c.bg}"
      xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/color2 --create --type string --set "${c.bg}"
      xfconf-query -c xfce4-desktop -p /desktop/icons/style --create --type int --set 0
      xfconf-query -c xfce4-desktop -p /desktop/icons/show-tooltips --create --type bool --set false
    '';
  };

  systemd.user.services.xfce4-desktop-setup = {
    Unit = {
      Description = "Configure XFCE desktop backdrop";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.config/xfce4/xfce4-desktop-setup.sh";
      RemainAfterExit = true;
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };
}
