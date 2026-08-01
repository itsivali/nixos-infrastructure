##############################################################################
#
# Desktop — KDE Frameworks
#
# Purpose
# -------
# KDE Frameworks system integration for the Hyprland desktop: Qt6/KF6
# runtime, KDE platform theme (native Qt file dialogs, KIO integration),
# Kvantum Qt widget style, and the standalone KRunner launcher
# (plasma-workspace provides the `krunner` binary + the Applications runner
# plugin that KDE Frameworks alone does not).
#
# Ownership
# ---------
# qt.enable, qt.platformTheme, qt.style, ivali.desktop.kde
#
# Responsibilities
# ----------------
# - Enable Qt configuration + the KDE platform theme
# - Use Kvantum as the Qt widget style (theme lives in home/hyprland/kde)
# - Install plasma-workspace so KRunner works standalone on Hyprland
# - Gate everything behind ivali.desktop.hyprland.enable
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.hyprland.enable or false) {
    # Qt integration: the "kde" platform theme installs kio,
    # plasma-integration and systemsettings, and sets QT_QPA_PLATFORMTHEME.
    qt.enable = true;
    qt.platformTheme = "kde";
    qt.style = "kvantum";

    environment.systemPackages = with pkgs; [
      # Standalone KRunner launcher (binary + Applications runner plugin).
      # kdePackages.krunner is only the framework library — the runnable
      # app and its runners ship in plasma-workspace.
      kdePackages.plasma-workspace

      # Breeze icons as a fallback icon theme for KDE/Qt applications.
      kdePackages.breeze-icons
    ];
  };
}
