##############################################################################
#
# Home — Hyprland Configuration Root
#
# Purpose
# -------
# Configures wayland.windowManager.hyprland with theme colors, animations,
# keybindings, window rules, and autostart background daemons.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  hl = (import ../themes).hyprland;
  animations = import ./animations.nix;
  rules = import ./rules.nix;
  monitors = import ./monitors.nix;
  keybindings = import ./keybindings.nix;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    configType = "hyprlang";

    settings = {
      inherit (monitors) monitor;
      inherit (animations) animations;
      inherit (rules) windowrule layerrule;
      inherit (keybindings) bind binde bindl bindm;

      exec-once = [
        # Propagate Wayland/X11 env to systemd user services (portals, keyring)
        "dbus-update-activation-environment --systemd --all"
        "waybar"
        "hypridle"
        # GNOME Keyring secret service (secrets for libsecret/NetworkManager,
        # ssh component for SSH key passphrases). Idempotent alongside the
        # PAM auto_start configured in desktop/login/ly.nix.
        "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets,ssh"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      ];

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = hl.activeBorder;
        "col.inactive_border" = hl.inactiveBorder;
        layout = "dwindle";
        resize_on_border = true;
      };

      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 0.95;
        blur = {
          enabled = true;
          size = 6;
          passes = 3;
          ignore_opacity = true;
          xray = false;
        };
        shadow = {
          enabled = true;
          range = 15;
          render_power = 3;
          color = hl.shadowColor;
        };
      };

      dwindle = {
        preserve_split = true;
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
        };
        sensitivity = 0;
      };

      gestures = {
        workspace_swipe_distance = 300;
        workspace_swipe_cancel_ratio = 0.5;
        workspace_swipe_create_new = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
      };
    };
  };
}
