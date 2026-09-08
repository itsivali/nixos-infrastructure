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
# - Configure the XFCE panel, window manager and desktop to the IVΛLI look
#
##############################################################################

{ ... }:

{
  imports = [
    ./terminal.nix
    ./mime.nix
    ./panel.nix
    ./dmenu.nix
  ];
}
