# AGENTS.md: The Complete AI Engineering Contract

This document defines the strict engineering contract for every AI agent working on this repository. It applies to all automated coding systems, including but not limited to: OpenCode, Claude Code, OpenAI Codex, GitHub Copilot, Google Jules, Gemini CLI, Cursor, Windsurf, Aider, Continue, and any future autonomous coding agents.

> **AI agents here are expected to operate as senior software engineers, not code generators.** The repository must remain in a production-ready state at all times.

---

## PART 1: Engineering Philosophy & The Contract

### 1.1 Core Philosophy

The primary goal of this repository is **not to generate code**, but to build and maintain a complete, polished, and reliable operating system environment.

- **Production-Grade:** Every implementation is treated as production software.
- **Holistic:** Every feature must feel complete and integrated.
- **End-to-End:** Every workflow must function from start to finish.
- **Zero Tolerance:** No unfinished features, dead code, duplicated modules, placeholder implementations, or partially completed work.

Whenever an AI agent makes a change, it assumes **total ownership** of ensuring the affected feature reaches production quality.

### 1.2 The Golden Rule: Never Stop at the First Success

A successful build, a passing test suite, a green CI pipeline, or a successful `nixos-rebuild` are **checkpoints, not finish lines.**

The task is only complete when:

1. The requested feature works flawlessly end-to-end.
2. Every affected workflow functions (e.g., Telegram bots receive, authenticate, execute, and respond to commands).
3. All regressions are fixed.
4. The implementation is polished.
5. Documentation matches reality.

**The Mandatory Iteration Loop:**
`Understand` ➔ `Implement` ➔ `Build` ➔ `Test` ➔ `Observe` ➔ `Fix Issues` ➔ `Refine` ➔ **`Repeat`**

If testing exposes an issue, fix it. Do not stop simply because the original prompt appears satisfied. The repository's health matters more than the individual task.

### 1.3 Definition of Done

A task is complete **only** when all of the following are explicitly true:

- [ ] The feature and its entire workflow function perfectly.
- [ ] Code meshes perfectly with Home Manager, NixOS, existing modules, and services.
- [ ] No `TODO`s, placeholders, magic values, or experimental hacks remain.
- [ ] All verification gates pass (`nix fmt`, `ivali verify`, `ivali doctor`, `nix flake check`, etc.).
- [ ] The repository is left in a cleaner, better state than it was found.

---

## PART 2: Repository Architecture & Organization

### 2.1 Flake and Module Architecture

This repository is driven by Nix Flakes. The architecture must remain strictly modular, composable, and updated.

- **Branch Tracking:** All core configuration files (including `flake.nix` and `ivali.nix`) must strictly track the `unstable` branch, rather than the stable release stream.

| Directory            | Purpose & Strict Rules                                                                                                               |
| :------------------- | :----------------------------------------------------------------------------------------------------------------------------------- |
| **`hosts/`**         | Contains machine-specific configurations. Must be minimal and only pull in required profiles/modules. No complex logic belongs here. |
| **`modules/nixos/`** | System-level NixOS modules. Must be highly parameterized using `lib.mkIf` and `lib.mkOption`.                                        |
| **`modules/home/`**  | User-level Home Manager modules. Must remain strictly unprivileged and declarative.                                                  |
| **`packages/`**      | Custom Nix packages and derivations. Must build entirely offline after source fetching.                                              |

### 2.2 Organization Conventions

- **One Module = One Capability:** Do not mix unrelated services.
- **Opt-In by Default:** All modules must be disabled by default (`config.modules.service.enable = false;`).
- **Absolute Paths:** Avoid relative paths in shell scripts and systemd services. Always use Nix string interpolation (e.g., `${pkgs.gnugrep}/bin/grep`).

---

## PART 3: Workflows, Verification, & CI/CD

### 3.1 Development & GitOps Workflow

Manual intervention is forbidden. The entire system must be reproducible from this repository via automated GitOps reconciliation loops.

- **Declarative Only:** Do not use imperative commands (`pip install`, `apt get`, `npm install -g`) to solve problems. If it is not in the Nix configuration, it does not exist.
- **State Management:** Any required state directories must be explicitly defined and handled via `tmpfs` or standard persistent storage declarations.

### 3.2 Verification Gates

Before considering any work complete, the agent MUST run and clear all applicable verification gates. Failures must always be fixed before completion.

- `nix fmt`: Enforces standard formatting.
- `nix flake check --no-build`: Validates the flake schema and syntax.
- `ivali verify` & `ivali doctor`: Custom repository health checks.
- `go test ./...`: Required whenever Go utilities or extensions are modified.

### 3.3 CI/CD Integration

If the task modifies CI workflows (e.g., GitHub Actions or GitLab CI):

- Ensure cache optimization is preserved.
- Jobs must run independently where possible, failing fast on syntax or formatting errors.

---

## PART 4: Security, Desktop Architecture & Maintenance

### 4.1 Security & Secrets Management

Security is a hard constraint.

- **No Plaintext Secrets:** Never commit passwords, API keys, or tokens.
- **Secrets Integration:** All sensitive data must be managed via secure deployment tools (e.g., `sops-nix` or `agenix`).
- **Principle of Least Privilege:** Systemd services must be locked down using standard hardening parameters (`DynamicUser = true`, `ProtectSystem = "strict"`, etc.) unless absolutely necessary.

### 4.2 Desktop & UI Architecture

When modifying the graphical environment or terminal spaces:

- **Terminal Integrity:** When modifying terminal configurations, ensure frameworks remain isolated as intended (e.g., retaining the Powerlevel10k framework while isolating Starship to a single segment).
- **Cohesion:** The user experience must feel intentional. Theming, fonts, and colors must utilize the centralized repository configuration.
- **End-to-End UI Testing:** Modifications to UI components require verification that launching, clicking, tooltips, and real-time updating work seamlessly.

### 4.3 Documentation Standards

- **README Requirements:** Every new module or significant package must include a local `README.md` explaining its purpose, options, and troubleshooting steps.
- **Self-Documenting Code:** Use Nix `description` fields robustly for all custom options.

### 4.4 Continuous Maintenance & Troubleshooting

- **Logging:** All custom scripts and services must output structured or highly readable logs to `journalctl`.
- **Rollback Readiness:** Every change must evaluate safely. Ensure configurations do not break NixOS rollback capabilities.
