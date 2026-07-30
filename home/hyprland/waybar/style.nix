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
    background-color: ${theme.css.bgA65};
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 14px;
    color: ${theme.colors.fg};
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
  #battery,
  #idle_inhibitor,
  #custom-notification,
  #custom-updates,
  #custom-power {
    background-color: ${theme.colors.bg1};
    padding: 4px 12px;
    margin: 4px 2px;
    border-radius: 10px;
    color: ${theme.colors.fg};
    border: 1px solid rgba(255, 255, 255, 0.05);
  }

  #custom-appmenu {
    color: ${theme.colors.accent};
    font-size: 16px;
    padding-left: 10px;
    padding-right: 14px;
  }

  #workspaces button {
    padding: 0 6px;
    color: ${theme.colors.gray};
    background-color: transparent;
    border-radius: 8px;
  }

  #workspaces button:hover {
    background-color: ${theme.colors.bg2};
    color: ${theme.colors.fg};
  }

  #workspaces button.active {
    color: ${theme.colors.accent};
    background-color: ${theme.colors.bg2};
  }

  #clock {
    color: ${theme.colors.aqua};
  }

  #cpu {
    color: ${theme.colors.green};
  }

  #memory {
    color: ${theme.colors.purple};
  }

  #pulseaudio {
    color: ${theme.colors.blue};
  }

  #backlight {
    color: ${theme.colors.yellow};
  }

  #network {
    color: ${theme.colors.aqua};
  }

  #battery {
    color: ${theme.colors.green};
  }

  #battery.warning {
    color: ${theme.colors.orange};
  }

  #battery.critical {
    color: ${theme.colors.red};
  }

  #idle_inhibitor {
    color: ${theme.colors.yellow};
  }

  #custom-notification {
    color: ${theme.colors.accent};
  }

  #custom-updates {
    color: ${theme.colors.blue};
  }

  #custom-power {
    color: ${theme.colors.red};
    padding-right: 12px;
  }
''
