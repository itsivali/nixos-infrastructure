##############################################################################
#
# Startup Dashboard
#
# Purpose
# -------
# Disabled — fastfetch removed from startup for faster shell launch.
# Use `ff` alias to run fastfetch manually.
#
# Order
# -----
# First — before anything that produces other output.
#
##############################################################################

{ pkgs, ... }:

{
  programs.zsh.initContent = ''
    ######################################################################
    # System dashboard — disabled for faster startup
    # Use `ff` to run fastfetch manually
    ######################################################################
  '';
}
