# desktop/default.nix
#
# Domain entry-point for desktop environment modules.
# Automatically imports every *.nix file placed in this directory.
#
# Current auto-discovered modules:
#   gnome-lean.nix  ← hardened GNOME + Wayland + power management
#
# To swap desktop environments, drop a new .nix here and remove
# (or disable with `enable = false` inside) gnome-lean.nix.
# To add extensions, theming, or input config: drop a .nix file here.
{ ... }:
{
  imports = import ../lib/auto-imports.nix ./.;
}
