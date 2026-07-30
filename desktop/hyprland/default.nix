##############################################################################
#
# Desktop Hyprland
#
# Purpose
# -------
# Main Hyprland desktop environment module. Configures system-level
# Hyprland session, GDM session discovery, Polkit authentication agent,
# PAM security for Hyprlock, and Wayland session environment variables.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Enable system-wide Hyprland & XWayland support
# - Configure PAM for hyprlock screen locking
# - Register XDG desktop portals (hyprland + gtk)
# - Enable Polkit authentication and power management services
# - Expose ivali.desktop.hyprland configuration options
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.hyprland;
in
{
  imports = [
    ./packages.nix
    ./portal.nix
  ];

  options.ivali.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop environment with themed components";

    theme = lib.mkOption {
      type = lib.types.enum [
        "gruvbox"
        "tokyo-night"
        "catppuccin"
        "nord"
        "everforest"
        "dracula"
      ];
      default = "gruvbox";
      description = "System theme preset for Hyprland desktop components";
    };
  };

  config = lib.mkIf cfg.enable {
    # System-wide Hyprland compositing & display manager integration
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

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      CLUTTER_BACKEND = "wayland";
    };
  };
}
