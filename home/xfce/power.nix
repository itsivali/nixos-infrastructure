##############################################################################
#
# Home — XFCE Power Management
#
# Purpose
# -------
# XFCE power-manager preferences. Deliberately disables screen blanking,
# DPMS, inactivity timeout and lock-on-suspend, and maps the physical power
# button to ask (menu) — configured in a dedicated module so the panel module
# owns only the panel/window-manager/shortcut surface.
#
# Ownership
# ---------
# xfce4-power-manager (xfconf channel)
#
# Does NOT Own
# ------------
# - Panel / window manager / shortcuts (panel.nix)
# - Desktop backdrop (backdrop.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  # Power-manager preferences are applied through a small setup script that
  # runs once at login (same pattern as the panel module). Kept separate so
  # this capability has an unambiguous owner.
  home.file.".config/xfce4/xfce4-power-manager-setup.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      # ── Power manager ──────────────────────────────────────────────────────
      xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac --create --type int --set 0
      xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-battery --create --type int --set 0
      xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled --create --type bool --set false
      xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/inactivity-on-ac --create --type int --set 0
      xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/inactivity-on-battery --create --type int --set 0
      xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-suspend-hibernate --create --type bool --set false
      xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/power-button-action --create --type int --set 0
    '';
  };

  systemd.user.services.xfce4-power-manager-setup = {
    Unit = {
      Description = "Configure XFCE power manager";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.config/xfce4/xfce4-power-manager-setup.sh";
      RemainAfterExit = true;
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };
}
