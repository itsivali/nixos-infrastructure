##############################################################################
#
# Developer Module
#
# Purpose
# -------
# Compose developer tooling modules for a senior staff engineer / SRE
# workflow. Covers language runtimes, DevOps tooling, local databases,
# and developer shell experience.
#
# Ownership
# ---------
# Imports only — all configuration is in sub-modules.
#
# Sub-modules (auto-imported via lib/auto-imports.nix):
#
#   Language Toolchains:
#   - go.nix         — Go toolchain (go, gopls, gotools, delve)
#   - node.nix       — Node.js/TypeScript (bun, nodejs, yarn, pnpm, ts)
#   - python.nix     — Python (python313, uv, ruff, black, mypy)
#   - kotlin.nix     — Kotlin/JVM (kotlin, kotlin-lsp, gradle)
#   - nix.nix        — Nix dev tools (alejandra, nixd, nil)
#
#   Platform Engineering:
#   - devops.nix     — IaC + K8s + Helm + Ansible + Vault + Consul + ArgoCD
#   - databases.nix  — Local dev databases (PostgreSQL + Valkey)
#
#   Developer Experience:
#   - aliases.nix    — Shell aliases (k8s, helm, tf, docker, go, db)
#   - shell.nix      — Default login shell (zsh)
#
#   AI Coding Agents:
#   - kilocode.nix    — Kilocode CLI (fork of OpenCode)
#   - antigravity.nix — Google Antigravity CLI (agy)
#   - ai-fallback.nix — `ai` wrapper: opencode → kilo → agy fallback chain
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
