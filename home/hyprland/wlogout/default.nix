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
  theme = import ../themes { inherit hostSpec; };
in
{
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "hyprlock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
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
        background-color: rgba(30, 30, 46, 0.85);
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
