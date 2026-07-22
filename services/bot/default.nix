##############################################################################
#
# Services Bot
#
# Purpose
# -------
# Barrel module for Telegram bot service sub-modules. Auto-imports all
# files in this directory via lib/auto-imports.nix.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Auto-import bot service sub-modules
#
##############################################################################

{ ... }:

{
  imports = import ../../lib/auto-imports.nix ./.;
}
