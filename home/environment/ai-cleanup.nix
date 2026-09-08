##############################################################################
#
# AI Coding Agent PATH Cleanup
#
# Purpose
# -------
# Removes legacy user-local AI tool binaries from ~/.local/bin that were
# installed imperatively (e.g. `agy` from the Antigravity installer script).
# The system-wide NixOS-managed versions take precedence after cleanup.
#
# This activation runs on every Home Manager switch and is idempotent —
# it only removes files that still exist at the path.
#
# Ownership
# ---------
# home.activation
#
##############################################################################

{ lib, ... }:

{
  home.activation.removeImperativeAiTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Remove legacy user-level agy binary installed by the Antigravity
    # installer script; the system-wide NixOS-managed version is used instead.
    if [ -f "$HOME/.local/bin/agy" ]; then
      echo "Removing legacy user-level agy binary from ~/.local/bin/agy"
      rm -f "$HOME/.local/bin/agy"
    fi
  '';
}
