##############################################################################
#
# Desktop — Hyprland Compositor
#
# Purpose
# -------
# System-level Hyprland compositing: session registration, PAM for hyprlock,
# core desktop daemons (polkit, upower, udisks2, gvfs), Bluetooth and power
# profile management. User-facing configuration (keybindings, bars, locks)
# lives in home/hyprland.
#
# Ownership
# ---------
# ivali.desktop.hyprland
#
# Responsibilities
# ----------------
# - Enable system-wide Hyprland + XWayland
# - Register the Hyprland Wayland session (discovered by Ly)
# - Configure PAM for hyprlock screen locking
# - Enable Polkit, power management and Bluetooth daemons
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.hyprland;
in
{
  config = lib.mkIf cfg.enable {
    # System-wide Hyprland compositing + Wayland session registration
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Screen locking security authentication (PAM)
    security.pam.services.hyprlock = { };

    # Core system daemons required for desktop operations
    security.polkit.enable = true;
    services.upower.enable = true;
    services.udisks2.enable = true;
    services.gvfs.enable = true;

    # Bluetooth (BlueZ service + stack for the blueman manager / waybar module)
    hardware.bluetooth.enable = true;

    # Power profile switching (power-saver / balanced / performance)
    services.power-profiles-daemon.enable = true;
  };
}
