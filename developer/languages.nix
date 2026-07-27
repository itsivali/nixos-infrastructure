##############################################################################
#
# Development Languages & Tools
#
# Purpose
# -------
# Barrel module for language-specific sub-modules. Language toolchains are
# split into focused sub-modules (go.nix, node.nix, python.nix, kotlin.nix,
# nix.nix) for independent maintainability.
#
# Ownership
# ---------
# Imports only — no direct configuration.
#
# Sub-modules (auto-imported):
#   - go.nix         — Go toolchain (go, gopls, gotools, delve)
#   - node.nix       — Node.js/TypeScript (bun, nodejs, yarn, pnpm, ts)
#   - python.nix     — Python (python313, uv, ruff, black, mypy)
#   - kotlin.nix     — Kotlin/JVM (kotlin, ksp, gradle)
#   - nix.nix        — Nix dev tools (alejandra, nixd, nil)
#   - devops.nix     — Platform engineering (terraform, k8s, helm, ansible)
#   - databases.nix  — Local dev databases (PostgreSQL + Valkey)
#   - aliases.nix    — Developer shell aliases
#
##############################################################################

{ ... }:
{
  # Language sub-modules are auto-imported by developer/default.nix
  # via lib/auto-imports.nix. This file exists for backward compatibility
  # and documentation purposes only.
}
