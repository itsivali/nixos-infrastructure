##############################################################################
#
# Development Aliases
#
# Purpose
# -------
# Developer tool shortcuts.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for development tools
#
# Responsibilities
# ----------------
# - fastfetch (ff)
# - lazygit (lg)
# - btop (bt)
# - ripgrep (rg)
# - fd (f)
# - Shell reload (reload)
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    ff = "fastfetch";
    lg = "lazygit";
    bt = "btop";
    rg = "rg";
    f = "fd";
    reload = "exec zsh";
    py = "python";
    serve = "python -m http.server";
    json = "jq";
    tldr = "tldr";
  };
}
