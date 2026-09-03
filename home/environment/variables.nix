##############################################################################
#
# Environment Variables
#
# Purpose
# -------
# Session-level environment variables for the user session. Includes
# editor, pager, locale, secrets, and development cache paths.
#
# Ownership
# ---------
# home.sessionVariables
#
##############################################################################

{ config, ... }:

{
  home.sessionVariables = {
    EDITOR = "zeditor";
    VISUAL = "zeditor";
    PAGER = "bat";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    LESS = "-R";
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";

    # Go build/module cache (XDG-compliant, survives GC)
    GOMODCACHE = "${config.xdg.cacheHome}/go-mod";
    GOCACHE = "${config.xdg.cacheHome}/go-build";
  };
}
