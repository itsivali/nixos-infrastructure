##############################################################################
#
# Development Languages & Tools
#
# Purpose
# -------
# Language runtimes and tooling installed system-wide.
#
# Ownership
# ---------
# environment.systemPackages for development tooling
#
# Does NOT Own
# ------------
# - Shell defaults (developer/shell.nix)
# - Docker (developer/docker.nix)
# - Editor config (home/editors/)
# - Shell tool packages (home/shell/tools/)
# - Git packages (home/git/)
#
##############################################################################

{ pkgs, ... }:

let
  tsxPackage = pkgs.tsx;
in
{
  environment.systemPackages = with pkgs; [
    alejandra

    go

    nodejs_22
    yarn
    typescript
    typescript-language-server
    tsxPackage

    python313
    python313Packages.ipython
    python313Packages.pytest
    uv
    ruff
    black
    mypy
  ];
}
