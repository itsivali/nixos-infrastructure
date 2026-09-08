##############################################################################
#
# Home — XFCE Panel, Window Manager & Workspaces
#
# Purpose
# -------
# Custom IVΛLI XFCE panel: Gruvbox-dark appearance, favorite-app launcher,
# numbered workspace switcher, window list, system tray, and clock. Also owns
# the xfwm4 window-manager behavior (theme, title font, button layout) and the
# workspace set + keyboard shortcuts that drive it. Power management and the
# desktop backdrop live in their own modules (power.nix / backdrop.nix) so each
# capability has a single owner.
#
# Ownership
# ---------
# xfce4-panel (panel), xfce4-xfwm4 (window manager), xfce4-keyboard-shortcuts
#
# Does NOT Own
# ------------
# - Power management (power.nix)
# - Desktop backdrop (backdrop.nix)
# - dmenu launcher (dmenu.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox;
  c = theme.colors;
in
{
  # Panel, xfwm4 and keyboard preferences are applied through a small setup
  # script because xfconf property paths contain slashes and are awkward to
  # express as nested Nix attribute sets. The script runs once at login via
  # the user's systemd --user instance and idempotently rewrites the panel /
  # xfwm4 / shortcuts channels from a single source of truth.
  home.file.".config/xfce4/xfce4-panel-setup.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      # ── Panel ──────────────────────────────────────────────────────────────
      xfconf-query -c xfce4-panel -p /panels -r -R >/dev/null 2>&1 || true
      xfconf-query -c xfce4-panel -p /panels --create --type int --set 1
      xfconf-query -c xfce4-panel -p /panels/panel-1/mode --create --type string --set "panel"
      xfconf-query -c xfce4-panel -p /panels/panel-1/x --create --type int --set 0
      xfconf-query -c xfce4-panel -p /panels/panel-1/y --create --type int --set 0
      xfconf-query -c xfce4-panel -p /panels/panel-1/width --create --type int --set 100
      xfconf-query -c xfce4-panel -p /panels/panel-1/height --create --type int --set 28
      xfconf-query -c xfce4-panel -p /panels/panel-1/length --create --type int --set 100
      xfconf-query -c xfce4-panel -p /panels/panel-1/strut --create --type bool --set true
      xfconf-query -c xfce4-panel -p /panels/panel-1/background-style --create --type int --set 0
      xfconf-query -c xfce4-panel -p /panels/panel-1/background-color --create --type string --set "${c.bg}"
      xfconf-query -c xfce4-panel -p /panels/panel-1/background-alpha --create --type double --set 1.0

      # ── Plugins ────────────────────────────────────────────────────────────
      xfconf-query -c xfce4-panel -p /plugins --create --type string --set ""

      # Launcher
      xfconf-query -c xfce4-panel -p /plugins/plugin-1/type --create --type string --set "launcher"
      xfconf-query -c xfce4-panel -p /plugins/plugin-1/items --create --type string --set "firefox.desktop"
      xfconf-query -c xfce4-panel -p /plugins/plugin-1/items --create --type string --set "thunar.desktop"
      xfconf-query -c xfce4-panel -p /plugins/plugin-1/items --create --type string --set "xfce4-terminal.desktop"
      xfconf-query -c xfce4-panel -p /plugins/plugin-1/items --create --type string --set "evince.desktop"
      xfconf-query -c xfce4-panel -p /plugins/plugin-1/items --create --type string --set "mousepad.desktop"
      xfconf-query -c xfce4-panel -p /plugins/plugin-1/items --create --type string --set "xfce4-settings-manager.desktop"
      xfconf-query -c xfce4-panel -p /plugins/plugin-1/items --create --type string --set "pavucontrol.desktop"

      # Workspace switcher
      xfconf-query -c xfce4-panel -p /plugins/plugin-3/type --create --type string --set "workspace-switcher"
      xfconf-query -c xfce4-panel -p /plugins/plugin-3/rows --create --type int --set 1
      xfconf-query -c xfce4-panel -p /plugins/plugin-3/show-numbers --create --type bool --set true
      xfconf-query -c xfce4-panel -p /plugins/plugin-3/show-window-names --create --type bool --set false
      xfconf-query -c xfce4-panel -p /plugins/plugin-3/arrow-type --create --type int --set 0

      # Window list
      xfconf-query -c xfce4-panel -p /plugins/plugin-5/type --create --type string --set "windowlist"
      xfconf-query -c xfce4-panel -p /plugins/plugin-5/show-window-icons --create --type bool --set true
      xfconf-query -c xfce4-panel -p /plugins/plugin-5/show-window-names --create --type bool --set true
      xfconf-query -c xfce4-panel -p /plugins/plugin-5/show-labels --create --type bool --set false
      xfconf-query -c xfce4-panel -p /plugins/plugin-5/include-all-workspaces --create --type bool --set false
      xfconf-query -c xfce4-panel -p /plugins/plugin-5/button-title --create --type bool --set false
      xfconf-query -c xfce4-panel -p /plugins/plugin-5/button-icon --create --type bool --set true

      # Systray
      xfconf-query -c xfce4-panel -p /plugins/plugin-7/type --create --type string --set "systray"
      xfconf-query -c xfce4-panel -p /plugins/plugin-7/names --create --type string --set "blueman"
      xfconf-query -c xfce4-panel -p /plugins/plugin-7/names --create --type string --set "pavucontrol"

      # Clock
      xfconf-query -c xfce4-panel -p /plugins/plugin-9/type --create --type string --set "clock"
      xfconf-query -c xfce4-panel -p /plugins/plugin-9/format --create --type string --set "%H:%M"
      xfconf-query -c xfce4-panel -p /plugins/plugin-9/tooltip-format --create --type string --set "%A %d %B %Y"
      xfconf-query -c xfce4-panel -p /plugins/plugin-9/show-week-numbers --create --type bool --set true

      # ── Window manager ─────────────────────────────────────────────────────
      xfconf-query -c xfce4-xfwm4 -p /general/theme --create --type string --set "Gruvbox-Dark"
      xfconf-query -c xfce4-xfwm4 -p /general/title_font --create --type string --set "Inter 9"
      xfconf-query -c xfce4-xfwm4 -p /general/button_layout --create --type string --set "O|SHMC"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_count --create --type int --set 10
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "α Web"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "β Term"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "γ Code"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "δ Docs"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "ε Files"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "ζ Mail"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "η Comm"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "θ Media"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "ι Sys"
      xfconf-query -c xfce4-xfwm4 -p /general/workspace_names --create --type string --set "κ Misc"

      # ── Keyboard shortcuts ─────────────────────────────────────────────────
      xfconf-query -c xfce4-keyboard-shortcuts -p /override --create --type bool --set true

      # Launchers: dmenu (Gruvbox theme) is the primary fuzzy launcher,
      # xfce4-appfinder remains as a fallback for the category view.
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>p' --create --type string --set "dmenu-run"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Alt>p' --create --type string --set "dmenu-run"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>space' --create --type string --set "xfce4-appfinder --collapsed"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Alt>F2' --create --type string --set "xfce4-appfinder --collapsed"

      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>1' --create --type string --set "workspace_1"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>2' --create --type string --set "workspace_2"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>3' --create --type string --set "workspace_3"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>4' --create --type string --set "workspace_4"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>5' --create --type string --set "workspace_5"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>6' --create --type string --set "workspace_6"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>7' --create --type string --set "workspace_7"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>8' --create --type string --set "workspace_8"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>9' --create --type string --set "workspace_9"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>0' --create --type string --set "workspace_10"

      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>1' --create --type string --set "move_window_to_workspace_1"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>2' --create --type string --set "move_window_to_workspace_2"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>3' --create --type string --set "move_window_to_workspace_3"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>4' --create --type string --set "move_window_to_workspace_4"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>5' --create --type string --set "move_window_to_workspace_5"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>6' --create --type string --set "move_window_to_workspace_6"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>7' --create --type string --set "move_window_to_workspace_7"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>8' --create --type string --set "move_window_to_workspace_8"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>9' --create --type string --set "move_window_to_workspace_9"
      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Shift><Super>0' --create --type string --set "move_window_to_workspace_10"

      xfconf-query -c xfce4-keyboard-shortcuts -p '/custom/<Super>Return' --create --type string --set "xfce4-terminal --drop-down"
    '';
  };

  # Run the setup script once at login after xfce4-session starts.
  systemd.user.services.xfce4-panel-setup = {
    Unit = {
      Description = "Configure XFCE panel, window manager, workspaces, and shortcuts";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.config/xfce4/xfce4-panel-setup.sh";
      RemainAfterExit = true;
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };
}
