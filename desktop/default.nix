# desktop/default.nix
#
# Domain entry-point for desktop environment modules.
# Automatically imports every *.nix file placed in this directory.
#
# Current modules:
#   gpu.nix         ← AMD GPU acceleration
#   gnome/          ← GNOME desktop, GDM, extensions, audio, packages
{ ... }:
{
  imports = [ ./gnome ] ++ import ../lib/auto-imports.nix ./.;
}
