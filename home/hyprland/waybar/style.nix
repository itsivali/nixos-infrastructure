##############################################################################
#
# Waybar Styling (Hyde Glassmorphic CSS)
#
# Purpose
# -------
# Glassmorphism, rounded pill widgets, smooth hover animations, and theme
# color synchronization for Waybar.
#
##############################################################################

{ theme }:

let
  wb = theme.waybar;
in
''
  * {
    border: none;
    border-radius: 0;
    font-family: "Inter", "MesloLGS NF", "Font Awesome 6 Free";
    font-size: 13px;
    font-weight: bold;
    min-height: 0;
  }

  window#waybar {
    background-color: ${wb.background};
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 14px;
    color: ${wb.text};
    transition-property: background-color;
    transition-duration: .5s;
  }

  #custom-appmenu,
  #workspaces,
  #window,
  #clock,
  #cpu,
  #memory,
  #pulseaudio,
  #backlight,
  #network,
  #bluetooth,
  #battery,
  #idle_inhibitor,
  #custom-notification,
  #custom-updates,
  #custom-power {
    background-color: ${wb.surface};
    padding: 4px 12px;
    margin: 4px 2px;
    border-radius: 10px;
    color: ${wb.text};
    border: 1px solid rgba(255, 255, 255, 0.05);
  }

  #custom-appmenu:hover,
  #workspaces button:hover,
  #clock:hover,
  #cpu:hover,
  #memory:hover,
  #pulseaudio:hover,
  #backlight:hover,
  #network:hover,
  #bluetooth:hover,
  #battery:hover,
  #idle_inhibitor:hover,
  #custom-notification:hover,
  #custom-updates:hover,
  #custom-power:hover {
    background-color: ${wb.surfaceAlt};
    border-color: ${wb.accent};
  }

  window#waybar tooltip {
    background-color: ${wb.bgA95};
    border: 1px solid ${wb.border};
    border-radius: 10px;
    color: ${wb.text};
  }

  window#waybar tooltip label {
    color: ${wb.text};
    font-weight: normal;
  }

  #custom-appmenu {
    color: ${wb.accent};
    font-size: 16px;
    padding-left: 10px;
    padding-right: 14px;
  }

  #workspaces button {
    padding: 0 6px;
    color: ${wb.textMuted};
    background-color: transparent;
    border-radius: 8px;
  }

  #workspaces button:hover {
    background-color: ${wb.surfaceAlt};
    color: ${wb.text};
  }

  #workspaces button.active {
    color: ${wb.accent};
    background-color: ${wb.surfaceAlt};
  }

  #clock {
    color: ${wb.aqua};
  }

  #cpu {
    color: ${wb.green};
  }

  #memory {
    color: ${wb.purple};
  }

  #pulseaudio {
    color: ${wb.blue};
  }

  #backlight {
    color: ${wb.yellow};
  }

  #network {
    color: ${wb.aqua};
  }

  #bluetooth {
    color: ${wb.blue};
  }

  #battery {
    color: ${wb.green};
  }

  #battery.warning {
    color: ${wb.accent};
  }

  #battery.critical {
    color: ${wb.red};
  }

  #idle_inhibitor {
    color: ${wb.yellow};
  }

  #custom-notification {
    color: ${wb.accent};
  }

  #custom-updates {
    color: ${wb.blue};
  }

  #custom-power {
    color: ${wb.red};
    padding-right: 12px;
  }
''
