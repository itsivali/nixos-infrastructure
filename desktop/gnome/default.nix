##############################################################################
#
# Desktop GNOME
#
# Purpose
# -------
# Main GNOME desktop environment module. Imports all GNOME sub-modules,
# declares the ivali.desktop.gnome.enable option, and configures core
# desktop services, session variables, and logind behavior.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Import audio, GDM, appearance, shell, applications, and tweaks modules
# - Declare the ivali.desktop.gnome.enable option
# - Enable GNOME desktop manager, polkit, gvfs, udisks2, upower
# - Set Wayland session variables (NIXOS_OZONE_WL, MOZ_ENABLE_WAYLAND)
# - Configure logind lid/power key handling
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  imports = [
    ./audio.nix
    ./gdm.nix
    ./appearance
    ./shell
    ./applications
    ./tweaks
  ];

  options.ivali.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment";
  };

  config = lib.mkIf cfg.enable {
    services.desktopManager.gnome.enable = true;

    security.polkit.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.accounts-daemon.enable = true;
    services.upower.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      GTK_USE_PORTAL = "1";
      XDG_SESSION_TYPE = "wayland";
    };

    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "lock";
      HandlePowerKey = "suspend";
      IdleAction = "ignore";
    };
  };
}
