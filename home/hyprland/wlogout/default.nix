##############################################################################
#
# Home — Wlogout Power Menu
#
# Purpose
# -------
# Declarative wlogout power options menu (lock, logout, suspend, reboot, shutdown).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes;
  iconFor = label: "${pkgs.wlogout}/share/wlogout/icons/${label}.png";
in
{
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "hyprlock";
        text = "Lock";
        image = iconFor "lock";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit";
        text = "Logout";
        image = iconFor "logout";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        image = iconFor "suspend";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        image = iconFor "hibernate";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        image = iconFor "reboot";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        image = iconFor "shutdown";
      }
    ];

    style = ''
      * {
        background-image: none;
        box-shadow: none;
        font-family: "Inter Bold";
        font-size: 14px;
      }

      window {
        background-color: ${theme.css.bgA85};
      }

      button {
        border-radius: 16px;
        color: ${theme.colors.fg};
        background-color: ${theme.colors.bg1};
        border: 2px solid ${theme.colors.bg2};
        margin: 10px;
        transition: all 0.2s ease-in-out;
      }

      button:hover {
        background-color: ${theme.colors.bg2};
        border-color: ${theme.colors.accent};
        color: ${theme.colors.accent};
      }
    '';
  };
}
