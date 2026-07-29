##############################################################################
#
# Home — Hypridle Idle Daemon
#
# Purpose
# -------
# Handles screen dimming, auto-locking, display power-off (DPMS), and system suspend.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        # 5 mins: dim brightness
        {
          timeout = 300;
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        # 10 mins: lock screen
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        # 15 mins: turn off display
        {
          timeout = 900;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        # 30 mins: suspend system
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
