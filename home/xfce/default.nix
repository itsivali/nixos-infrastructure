##############################################################################
#
# Home — XFCE
#
# Purpose
# -------
# User-level (Home Manager) configuration for the XFCE desktop: terminal
# theming, XFCE panel/session, and the XFCE MIME default application stack.
#
# Ownership
# ---------
# ivali.desktop.xfce (user side)
#
# Responsibilities
# ----------------
# - Apply the Gruvbox theme to xfce4-terminal
# - Declare the XFCE MIME handler set (Thunar, Ristretto, evince, Xarchiver,
#   mousepad, xfce4-terminal)
# - Configure the custom panel, window manager and workspaces (panel.nix)
# - Theme the dmenu launcher (dmenu.nix)
# - Configure XFCE power management (power.nix)
# - Configure the desktop backdrop (backdrop.nix)
#
##############################################################################

{ ... }:

{
  imports = [
    ./terminal.nix
    ./mime.nix
    ./panel.nix
    ./dmenu.nix
    ./power.nix
    ./backdrop.nix
  ];
}
