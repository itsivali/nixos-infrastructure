# AGENTS.md: The Complete AI Engineering Contract

This document defines the strict engineering contract for every AI agent working on this repository.It applies to all automated coding systems, including but not limited to: OpenCode, Claude Code, OpenAI Codex, GitHub Copilot, Google Jules, Gemini CLI, Cursor, Windsurf, Aider, Continue, and any future autonomous coding agents.

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
- `golangci-lint run`: Required whenever Go code is modified. The `go-lint` CI job **must** pass — no `continue-on-error`, no exceptions. Fix all lint issues before pushing.

### 3.3 CI/CD Integration

If the task modifies CI workflows (e.g., GitHub Actions or GitLab CI):

- Ensure cache optimization is preserved.
- Jobs must run independently where possible, failing fast on syntax or formatting errors.

### 3.4 Commit & Push Gate

The work is not released until every verification gate passes **and** the change is pushed to GitLab:

1. Clear all gates in §3.2. Never skip a failing gate.
2. **`golangci-lint run` must pass.** The `go-lint` CI job is a required gate — no `continue-on-error`, no exceptions. Fix all lint issues before pushing. If you cannot fix a lint issue, explain why in a comment and open an issue.
3. Commit with a concise, conventional message and no local-only changes, secrets, or debug artifacts.
4. **One logical change per commit.** Do not bundle unrelated concerns (e.g., bug fixes, feature wiring, and secret rotations) into a single commit; split mixed changes into separate, independently buildable commits before pushing. `git reset --mixed HEAD~1` followed by `git add -p` is the standard way to recover an already-mixed commit.
5. Push to **GitLab** (`git push origin main`) — GitLab is the single source of truth. Never push to GitHub directly; the GitHub mirror updates automatically from GitLab.
6. Confirm the GitHub Actions run on the mirror goes green before declaring the work complete.

If a gate fails after a commit, fix the issue and create a new commit; do not amend the failed one.

### 3.5 Testing Requirements

Every code change must be verified before committing. No exceptions.

**Pre-commit verification checklist (mandatory for every session):**

1. **Nix formatting:** `nix fmt` — all `.nix` files must pass.
2. **Nix evaluation:** `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.name` — must evaluate without error.
3. **Go compilation:** `go build ./...` — must compile cleanly.
4. **Go tests:** `go test ./...` — all tests must pass.
5. **Shell lint:** `shellcheck scripts/*.sh` — if scripts are modified.

**End-to-end feature testing:**

- Every feature must be tested from the user's perspective, not just compilation.
- Desktop changes: verify launching apps, keybindings, theming, sidebar behavior.
- Service changes: verify systemd unit starts, logs are clean, health checks pass.
- Script changes: verify the script runs correctly with realistic inputs.
- Go changes: verify the CLI/bot produces correct output for representative commands.

**Logic-level testing:**

- Every function must have at least one test case covering its primary behavior.
- Every conditional branch must be exercised by at least one test.
- Edge cases (empty input, missing files, permission errors) must be tested where applicable.
- Tests must be deterministic — no flaky tests, no time-dependent assertions.

**Code completeness:**

- No stub implementations (e.g., `return nil`, `return "default"`) in production code.
- No `TODO`/`FIXME`/`HACK` comments indicating incomplete work.
- No dead code (unexported functions never called, unused variables, unreachable branches).
- No duplicate implementations — extract shared logic to utility packages.
- All options declared in Nix modules must be consumed by at least one configuration path.
- Every registered check/test must have a non-trivial implementation (not a no-op).

**Commit discipline:**

- One logical change per commit. Never bundle unrelated concerns.
- Each commit must independently pass all verification gates.
- Use `git add -p` to split mixed changes into separate commits.
- Commit messages must follow conventional format: `type(scope): description`.

---

## PART 4: Security, Desktop Architecture & Maintenance

### 4.1 Security & Secrets Management

Security is a hard constraint.

- **No Plaintext Secrets:** Never commit passwords, API keys, or tokens.
- **No Hardcoded Secrets:** Never hardcode secret values — not even as fallbacks, defaults, or placeholder credentials. Every secret must live exclusively in SOPS-encrypted files under `secrets/`. This includes Grafana secret keys, admin passwords, API tokens, and any other credential. If a module needs a secret, declare it via `sops.secrets.<name>.sopsFile`. Test VMs that cannot decrypt SOPS must provide throwaway values directly on the NixOS service settings — never embed them in the module.
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

---

## PART 5: Architectural Audit & Enforcement Framework

This section defines the comprehensive architectural governance contract. Every AI agent must internalize these phases before performing any structural work on the repository.

### 5.1 Role Definition

You are the lead systems architect and senior NixOS infrastructure engineer taking ownership of this repository. Your responsibility is to audit, understand, refactor, isolate, test, and enforce the architecture.

You are NOT starting a greenfield project. You are working on an existing, functional, highly customized NixOS infrastructure repository. Your job is to improve its architecture without destroying existing functionality.

### 5.2 Primary Objective

Transform the repository into a:

> Strongly modular, domain-oriented, dependency-aware NixOS infrastructure platform with explicit boundaries, isolated runtime services, clear ownership, reproducible builds, and CI-enforced architectural rules.

The goal is that a developer can work on one subsystem without accidentally modifying or breaking unrelated subsystems.

For example: modifying GNOME should NOT unexpectedly affect Telegram, GitOps, Tailscale, Firewall, Security, or Observability. Likewise, modifying Telegram should not require changing GNOME implementation.

### 5.3 Hybrid Architecture Principle

Do NOT interpret this as "turn every NixOS module into a microservice." Implement a hybrid architecture:

**Declarative domains** — Strongly isolated NixOS/Home Manager modules for: boot, hardware, kernel, desktop, GNOME, networking, Tailscale, security, packages, developer tooling, secrets, recovery, etc.

**Runtime services** — Isolated service boundaries for things that actually behave as services: Telegram Control Plane, GitOps, Observability, Backup, Self-Healing, Automation, etc.

Runtime services must communicate through explicit interfaces rather than directly modifying one another's implementation or state.

### 5.4 Phases of Architectural Governance

#### Phase 0 — Stop and Understand the Repository

Before changing anything: DO NOT MOVE FILES, DO NOT DELETE FILES, DO NOT REWRITE MODULES, DO NOT CHANGE ARCHITECTURE, DO NOT "CLEAN UP" RANDOMLY. First inspect the repository using `git status`, `git branch`, `git log`, `git diff`, `find`, `tree`, `rg`, `git grep`, `nix eval`, `nix flake check`.

#### Phase 1 — Complete Architectural Audit

Inspect at minimum: `flake.nix`, `flake.lock`, `configuration.nix`, and every top-level directory. Determine ownership from actual behavior, not directory names.

#### Phase 2 — Inventory Everything

Build an inventory of: Nix modules, Home Manager modules, systemd services, systemd timers, scripts, executables, packages, secrets, configuration files, generated files, state directories, runtime sockets, network dependencies, host-specific configuration, CI jobs, automation, external dependencies.

For every significant component determine: Name, Path, Domain, Owner, Type, Public interface, Internal implementation, Dependencies, Consumers, State, Filesystem access, Runtime dependencies, Network dependencies, Secrets, Side effects, Host dependencies.

#### Phase 3 — Build the Real Dependency Graph

Determine dependencies from the source. Track: Nix dependencies (imports, option references, config references, flake inputs, package references), Runtime dependencies (systemd Requires/Wants/After/Before/BindsTo/PartOf/ExecStart*), Script dependencies (sourced scripts, commands, binaries, environment variables, files, sockets, directories), Filesystem dependencies (/etc, /var/lib, /var/cache, /run, /home, /opt, other persistent state).

#### Phase 4 — Produce Dependency Graphs

Create `ARCHITECTURE_AUDIT.md` with actual dependency graphs using Mermaid where practical. The final graph MUST reflect the actual repository. Do not invent dependencies.

#### Phase 5 — Create a Runtime Service Graph

Create a separate graph for runtime services showing: Telegram, GitOps, Backup, Monitoring, Self-Healing, Automation and their real dependencies. The graph must show service interactions, not filesystem paths.

#### Phase 6 — Find Circular Dependencies

Detect all dependency cycles (A → B → C → A). For every cycle document: Source, Complete cycle, Why it exists, Whether it is legitimate, Risk, Proposed resolution. Do not break legitimate NixOS module relationships merely because they appear circular.

#### Phase 7 — Find Cross-Domain Coupling

Identify cases where one domain directly depends on another domain's implementation. These should be considered violations unless explicitly documented as exceptions.

#### Phase 8 — Find Cross-Domain Filesystem Access

Find all cases where one domain accesses another domain's state. Inspect shell scripts for file operations against another subsystem's private files. Classify every finding as: Allowed, Questionable, Forbidden.

#### Phase 9 — Find Duplicate Configuration

Search for duplicate systemd services, firewall rules, packages, GNOME configuration, environment variables, secrets configuration, networking configuration, GTK settings, dconf configuration, Home Manager configuration. The goal is: one authoritative owner for each configuration concern.

#### Phase 10 — Find Undeclared Dependencies

Find dependencies that happen to work only because something else installs or configures them. Every dependency must be explicit.

#### Phase 11 — Find Internal API Violations

Every domain must eventually have PUBLIC and INTERNAL boundaries. Another domain must not directly consume internal paths unless the dependency is explicitly approved and documented.

#### Phase 12 — Find Cross-Service State Mutation

A service MUST NOT directly modify another service's private state. A service may request another service to change its state via an interface. It must not own or directly mutate that state.

#### Phase 13 — Design Domain Boundaries

After completing the audit, define the actual domains. Derive domain boundaries from the actual repository. For each domain document: Purpose, Owner, Public API, Internal implementation, Allowed dependencies, Forbidden dependencies, State ownership, Filesystem ownership, Runtime services, Tests.

#### Phase 14 — Dependency Direction

Establish a one-directional dependency hierarchy. Dependencies must flow in a controlled direction. Avoid domain-to-domain cycles.

#### Phase 15 — Host Composition

Hosts should compose capabilities (e.g., `modules.desktop.gnome.enable = true`). Hosts should NOT contain subsystem implementation.

#### Phase 16 — Public Contracts

Every domain must expose a small public interface. Consumers should depend on public options/contracts. They should not reach into implementation files.

#### Phase 17 — State Ownership

Every state directory must have exactly one owner. Create a state ownership table documenting: path, owner, consumers, mutation authority.

#### Phase 18 — Configuration Ownership

For every major configuration concern determine: Owner, Consumers, Mutation authority. Avoid multiple owners.

#### Phase 19 — Architecture Manifest

Create a machine-readable architecture manifest (`architecture/domains.yaml`, `architecture/dependencies.yaml`, `architecture/exceptions.yaml`) describing: domain, paths, public paths, internal paths, allowed dependencies, forbidden dependencies, state ownership.

#### Phase 20 — Architectural Exceptions

Create `architecture/exceptions.yaml`. Every exception must specify: source, target, reason, owner, review/expiry. Never hide architectural exceptions.

#### Phase 21 — Build the Architecture Linter

Implement a dedicated architecture checker that validates: (1) Forbidden imports, (2) Circular dependencies, (3) Cross-domain filesystem access, (4) Duplicate configuration, (5) Undeclared dependencies, (6) Internal module access, (7) Cross-service state mutation. The implementation should be deterministic, fast, dependency-light, testable, readable, CI-friendly.

#### Phase 22 — Local Architecture Command

Create a simple developer command (e.g., `./ci/check-architecture`) that runs all architecture checks and reports PASS/FAIL with exit non-zero on failure.

#### Phase 23 — Test the Architecture Checker

Create fixtures for: valid architecture, forbidden import, circular dependency, filesystem violation, duplicate configuration, undeclared dependency, internal API violation, cross-service state mutation. The tests must prove the checker catches each violation.

#### Phase 24 — CI Integration

Integrate architecture validation into the existing CI system. Architecture validation must run before expensive builds. Preferred flow: lint → architecture → tests → flake check → build.

#### Phase 25 — CI Must Protect the Architecture

After migration, someone should not be able to add a forbidden cross-domain dependency without CI failing. The architecture must become self-enforcing.

#### Phase 26 — Migration

Only after audit, graph, domain design, architecture manifest, checker, and checker tests are complete should the repository migration begin. Migrate incrementally. Recommended order: (1) Establish boundaries, (2) Establish ownership, (3) Add public interfaces, (4) Remove internal dependencies, (5) Fix filesystem coupling, (6) Fix undeclared dependencies, (7) Break cycles, (8) Separate runtime service state, (9) Remove obsolete code, (10) Enable strict CI enforcement.

#### Phase 27 — Preserve Existing Functionality

This is NOT a feature rewrite. Preserve existing functionality. Pay particular attention to: NixOS boot, GNOME, Home Manager, Tailscale, firewall, SSH, secrets, GitOps, GitLab Runner, Telegram control plane, observability, self-healing, recovery, developer environment.

#### Phase 28 — Dead Code

During the audit identify: unused modules, unused scripts, obsolete services, duplicate scripts, unreachable code, dead configuration, obsolete remnants, abandoned automation, unused packages. Classify as: ACTIVE, LEGACY, DEAD, UNCERTAIN. Only remove code when you can establish that it is dead or explicitly obsolete.

#### Phase 29 — NixOS Validation

After each meaningful migration run `nix flake check`. Use targeted evaluation/build checks where appropriate. Do not repeatedly run expensive full system switches. Prefer: `nix flake check`, `nix eval`, `nixos-rebuild build --flake .`.

#### Phase 30 — No Architectural Magic

Do not solve coupling by introducing: giant shared modules, global mutable state, hidden environment variables, undocumented shell scripts, arbitrary symlinks, implicit dependencies, filesystem hacks. If two domains need to communicate, define a contract.

#### Phase 31 — Runtime Service Contracts

For services such as Telegram, GitOps, Backup, Monitoring, Self-Healing, define explicit interfaces. Choose the simplest appropriate mechanism (Unix sockets, CLI interfaces, systemd interfaces, local HTTP APIs, structured files). Do not introduce network APIs merely because "microservices" sounds modern.

#### Phase 32 — Document the Architecture

Create `ARCHITECTURE_AUDIT.md` and `ARCHITECTURE_PROGRESS.md`. The audit must explain: current architecture, domains, dependencies, dependency graph, runtime graph, cycles, coupling, filesystem violations, duplicate configuration, undeclared dependencies, internal API violations, state ownership violations, proposed architecture, migration plan. The progress document must contain: completed, current phase, known violations, tests, remaining work, exact next step.

#### Phase 33 — Context Handoff

NEVER leave the repository in an ambiguous state. At the end of every major phase update `ARCHITECTURE_PROGRESS.md` with the exact state of the work. If running out of context: STOP. Document what was completed, what changed, what remains, what failed, and the exact next action.

#### Phase 34 — Final Acceptance Test

The architecture transformation is complete only when ALL of the following are true:

- [ ] Repository fully audited
- [ ] Actual dependency graph created
- [ ] Runtime dependency graph created
- [ ] Domains defined
- [ ] Domain ownership documented
- [ ] Public interfaces defined
- [ ] Internal implementations isolated
- [ ] State ownership defined
- [ ] Filesystem ownership defined
- [ ] Circular dependencies eliminated or explicitly justified
- [ ] Forbidden imports eliminated
- [ ] Cross-domain filesystem access eliminated or documented
- [ ] Duplicate configuration eliminated
- [ ] Undeclared dependencies eliminated
- [ ] Internal API violations eliminated
- [ ] Cross-service state mutation eliminated
- [ ] Architecture manifest implemented
- [ ] Architecture exceptions documented
- [ ] Architecture linter implemented
- [ ] Architecture linter tested
- [ ] CI integration implemented
- [ ] CI rejects architectural violations
- [ ] Existing CI continues working
- [ ] Nix flake check passes
- [ ] Relevant tests pass
- [ ] Existing functionality preserved
- [ ] Dead code identified and appropriately handled
- [ ] Documentation complete

### 5.5 Final Target Architecture

The final repository should behave like this:

```
┌─────────────────────┐
│       prague        │
│        HOST         │
└──────────┬──────────┘
│
COMPOSITION ONLY
│
┌──────────────────────┼──────────────────────┐
│                      │                      │
▼                      ▼                      ▼
DESKTOP              NETWORKING              SECURITY
│                      │                      │
▼                      ▼                      ▼
INTERNAL               INTERNAL               INTERNAL


RUNTIME SERVICES

┌─────────────┐       ┌─────────────┐
│  TELEGRAM   │──────▶│   GITOPS    │
└─────────────┘ API   └─────────────┘
│
▼
OWNED STATE


┌─────────────┐
│   BACKUP    │
└──────┬──────┘
│
│ API / approved interface
▼
SERVICE-OWNED STATE
```

The following must NEVER happen:
- Telegram directly modifying /var/lib/gitops
- GNOME reaching into Telegram internals
- Networking reaching into GitOps internals
- Any circular dependency chain (A → B → C → A)

### 5.6 Most Important Instruction

Do not simply produce an architecture document. Do not simply recommend a new directory structure. Actually: AUDIT → MODEL → GRAPH → DESIGN → IMPLEMENT → TEST → ENFORCE → DOCUMENT.

The repository must end up with architectural boundaries that are: explicit, testable, reproducible, enforceable, maintainable. The ultimate goal is: a developer or LLM can modify one subsystem without accidentally coupling, breaking, or modifying unrelated subsystems — and CI automatically prevents architectural regression.






