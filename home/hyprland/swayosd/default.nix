##############################################################################
#
# Home — SwayOSD On-Screen Display
#
# Purpose
# -------
# SwayOSD server and on-screen display for volume, brightness and microphone
# changes, themed with Gruvbox colors. Autostarts with the Hyprland session
# via the swayosd systemd user unit.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Run swayosd-server as a user service on hyprland-session.target
# - Provide a Gruvbox stylesheet for the OSD window
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../themes;
in
{
  home.file."config/swayosd/style.css".text = ''
    window#osd {
      border-radius: 16px;
      border: 1px solid ${theme.colors.accent};
      background-color: ${theme.css.bgA85};
      padding: 16px;
    }

    #container {
      margin: 6px 12px;
    }

    #icon {
      color: ${theme.colors.fg};
    }

    progressbar {
      min-height: 8px;
      border-radius: 4px;
      background-color: ${theme.colors.bg2};
    }

    progressbar trough {
      background-color: ${theme.colors.bg2};
      border-radius: 4px;
    }

    progressbar progress {
      background-color: ${theme.colors.accent};
      border-radius: 4px;
    }
  '';

  services.swayosd = {
    enable = true;
    topMargin = 0.3;
    stylePath = "${config.xdg.configHome}/swayosd/style.css";
  };
}
