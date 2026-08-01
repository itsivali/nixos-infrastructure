##############################################################################
#
# Home — KDE Frameworks
#
# Purpose
# -------
# Barrel for user-level KDE Frameworks configuration: Kvantum Qt theming,
# and future KDE app tweaks that don't belong in system-level desktop/kde.
#
# Ownership
# ---------
# home.hyprland.kde
#
##############################################################################

{ ... }:

{
  imports = [
    ./kvantum.nix
  ];
}
