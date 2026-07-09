# desktop/default.nix
#
# Domain entry-point for desktop environment modules.
# Automatically imports every *.nix file placed in this directory.
#
# Current modules:
#   gnome-lean.nix  ← GNOME + Wayland + power management
#   gpu.nix         ← AMD GPU acceleration
#   desktop-control.nix — GNOME Shell extension for bot integration
{ ... }:
{
  imports = import ../lib/auto-imports.nix ./.;
}
