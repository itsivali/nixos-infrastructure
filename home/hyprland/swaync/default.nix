##############################################################################
#
# Home — SwayNC Notification Center
#
# Purpose
# -------
# Declarative SwayNC notification center daemon with theme colors, media player
# controls, volume & brightness sliders, and DND controls.
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
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      cssPriority = "user";

      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;
      control-center-margin-left = 10;

      notification-2fa-action = true;
      notification-inline-replies = true;
      notification-icon-size = 48;
      notification-body-image-height = 100;
      notification-body-image-width = 200;

      widgets = [
        "title"
        "dnd"
        "notifications"
        "mpris"
        "volume"
        "backlight"
      ];

      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear All";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        mpris = {
          image-size = 60;
          image-radius = 12;
        };
        volume = {
          label = "󰕾";
        };
        backlight = {
          label = "󰃠";
        };
      };
    };

    style = ''
      * {
        font-family: "Inter", "MesloLGS NF";
        font-size: 13px;
      }

      .notification-row {
        outline: none;
      }

      .notification {
        background: ${theme.colors.bg1};
        border: 1px solid ${theme.colors.bg2};
        border-radius: 12px;
        color: ${theme.colors.fg};
        margin: 6px;
        padding: 8px;
      }

      .notification-content {
        background: transparent;
      }

      .control-center {
        background: ${theme.colors.bg}d9;
        border: 1px solid ${theme.colors.accent};
        border-radius: 16px;
        color: ${theme.colors.fg};
        padding: 14px;
      }

      .widget-title {
        color: ${theme.colors.accent};
        font-weight: bold;
        font-size: 16px;
      }

      .widget-dnd {
        background: ${theme.colors.bg2};
        border-radius: 8px;
        color: ${theme.colors.fg};
        padding: 8px;
        margin: 6px 0;
      }
    '';
  };
}
