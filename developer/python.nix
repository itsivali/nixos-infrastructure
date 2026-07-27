##############################################################################
#
# Python Toolchain
#
# Purpose
# -------
# Python runtime and development tools including package management,
# linting, formatting, type checking, and interactive shells.
#
# Ownership
# ---------
# environment.systemPackages for Python tooling
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python313
    python313Packages.ipython
    python313Packages.pytest
    uv
    ruff
    black
    mypy
  ];
}
