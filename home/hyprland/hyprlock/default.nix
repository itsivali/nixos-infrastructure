##############################################################################
#
# Home — Hyprlock Screen Locker
#
# Purpose
# -------
# GPU-accelerated screen locker for Hyprland featuring background blur,
# clock widget, user avatar, and Hyde theme integration.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, hostSpec, ... }:

let
  theme = import ../themes;
in
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 0;
        no_fade_in = false;
      };

      background = [
        {
          monitor = "";
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "250, 50";
          outline_thickness = 3;
          dots_size = 0.2;
          dots_spacing = 0.2;
          dots_center = true;
          outer_color = theme.colors.accent;
          inner_color = theme.colors.bg1;
          font_color = theme.colors.fg;
          fade_on_empty = false;
          placeholder_text = "<i>Enter Password...</i>";
          hide_input = false;
          position = "0, -80";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          color = theme.colors.fg;
          font_size = 64;
          font_family = "Inter Bold";
          position = "0, 100";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "Hi, $USER";
          color = theme.colors.accent;
          font_size = 20;
          font_family = "Inter";
          position = "0, 0";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
