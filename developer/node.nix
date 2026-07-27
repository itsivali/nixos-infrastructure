##############################################################################
#
# Node.js / TypeScript Toolchain
#
# Purpose
# -------
# JavaScript/TypeScript runtime, package managers, and development tools.
# Covers Node.js, Bun, Yarn, pnpm, TypeScript, and formatters/linters.
#
# Ownership
# ---------
# environment.systemPackages for Node.js/TypeScript tooling
#
# Does NOT Own
# ------------
# - Editor LSP config (home/editors/)
# - Shell tool config (home/shell/tools/)
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Runtimes
    bun
    nodejs_22
    yarn
    pnpm

    # TypeScript
    typescript
    typescript-language-server
    tsx

    # Linting & Formatting
    eslint
    prettier
  ];
}
