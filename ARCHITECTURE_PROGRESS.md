# Architecture Progress

> Tracks the state of the architectural audit and enforcement work.
> Last updated: Session 3 — Phase 26 HIGH violations resolved.

---

## Completed

- [x] **Phase 0** — Repository understood (git status, branch, log, structure)
- [x] **Phase 1** — Complete architectural audit (187 Nix files, 127 Go files, 16 scripts, ~40 services)
- [x] **Phase 2** — Full inventory built (modules, services, timers, scripts, packages, secrets, state, CI)
- [x] **Phase 3** — Real dependency graph determined from source (Nix imports, runtime deps, script deps, filesystem deps)
- [x] **Phase 4** — Dependency graphs produced (ARCHITECTURE_AUDIT.md with Mermaid diagrams)
- [x] **Phase 5** — Runtime service graph created
- [x] **Phase 6** — Circular dependencies: **NONE FOUND**
- [x] **Phase 7** — Cross-domain coupling: **7 findings** (C1-C7)
- [x] **Phase 8** — Cross-domain filesystem access: **8 findings** (F1-F8)
- [x] **Phase 9** — Duplicate configuration: **7 findings** (D1-D7), including 1 HIGH severity conflict
- [x] **Phase 10** — Undeclared dependencies: **6 findings** (U1-U6)
- [x] **Phase 11** — Internal API violations: **NONE** (no internal/ directories exist yet)
- [x] **Phase 12** — Cross-service state mutation: **2 findings** (S1-S2)
- [x] **Phase 13** — Domain boundaries designed (5-level hierarchy)
- [x] **Phase 14** — Dependency direction established (one-directional, no upward deps)
- [x] **Phase 15** — Host composition documented (pure data + template)
- [x] **Phase 16** — Public contracts identified (fleet.*, ivali.* option namespaces)
- [x] **Phase 17** — State ownership table created (12 paths, 2 violations, 1 unowned)
- [x] **Phase 18** — Configuration ownership mapped (7 duplicate findings)
- [x] **Phase 19** — Architecture manifests: `domains.yaml`, `dependencies.yaml`, `exceptions.yaml`
- [x] **Phase 20** — Architecture exceptions: 10 documented exceptions (EXC-001 through EXC-010)
- [x] **Phase 21** — Architecture linter: 7 checks implemented in Go (`internal/architecture/`)
- [x] **Phase 22** — Local command: `ci/check-architecture` shell wrapper
- [x] **Phase 23** — Linter tests: 5 tests, all passing (`internal/architecture/linter_test.go`)
- [x] **Phase 24** — CI integration: architecture-check job in GitHub Actions (non-blocking)
- [x] **Phase 25** — CI enforcement: architecture check reports violations, blocking once clean
- [x] **Phase 26** — Incremental migration: HIGH severity violations resolved
- [x] **AGENTS.md** — Architectural role added as PART 5
- [x] **Firefox** — Launcher rail unhidden + Gruvbox-themed

## In Progress

- [ ] **Phase 27** — Preserve existing functionality verification

## Not Started

- [ ] **Phase 28** — Dead code audit (preliminary: none found)
- [ ] **Phase 29** — NixOS validation (nix flake check)
- [ ] **Phase 30** — No architectural magic verification
- [ ] **Phase 31** — Runtime service contracts
- [ ] **Phase 32** — Full documentation
- [ ] **Phase 33** — Context handoff document
- [ ] **Phase 34** — Final acceptance test

## Phase 26 Resolution Summary

| # | Violation | Resolution | Commit |
|---|-----------|------------|--------|
| 1 | `loki` CPUQuota conflict (15% vs 10%) | Consolidated into `grafana.nix` (10%), removed from `loki.nix` | `3afddbf` |
| 2 | Hardcoded `HOST="prague"` in scripts | Replaced with `${HOST_NAME:-$(hostname)}` pattern | `1b4d76e` |
| 3 | `/var/lib/gitops` no formal owner | Added `StateDirectory = "gitops"` to `gitops-reconciler.service` | `f1ca0e9` |
| 4 | Hardcoded `prague` in Go files | Replaced with `os.Hostname()` fallback | `549e2a4` |

## Known Violations (Priority Order)

| # | Severity | Category | Description | Exception | Status |
|---|----------|----------|-------------|-----------|--------|
| ~~1~~ | ~~**HIGH**~~ | ~~Duplicate config~~ | ~~`loki` CPUQuota conflict: 15% vs 10%~~ | — | ~~Resolved~~ |
| ~~2~~ | ~~**HIGH**~~ | ~~Hardcoded hostname~~ | ~~5 shell scripts hardcode `HOST="prague"`~~ | — | ~~Resolved~~ |
| ~~3~~ | ~~**HIGH**~~ | ~~Hardcoded hostname~~ | ~~4 Go files hardcode `prague` deploy target~~ | — | ~~Resolved~~ |
| ~~4~~ | ~~**HIGH**~~ | ~~State ownership~~ | ~~`/var/lib/gitops` has no formal owner~~ | EXC-003/004 | ~~Resolved~~ |
| 5 | **MEDIUM** | Cross-domain coupling | `ci-notify.nix` gates on `fleet.gitlabRunner.enable` | EXC-007 | Open |
| 6 | **MEDIUM** | Cross-domain coupling | `deployment-health.nix` reads `fleet.gitops` options | EXC-008 | Open |
| 7 | **MEDIUM** | Cross-domain coupling | `gitlab-runner.nix` reads `fleet.gitops` options | EXC-009 | Open |
| 8 | **MEDIUM** | Filesystem access | `security/apparmor.nix` hardcodes bot paths | EXC-005 | Open |
| 9 | **MEDIUM** | Duplicate config | `prometheus`/`node-exporter` resource limits duplicated | — | Resolved |
| 10 | **MEDIUM** | Duplicate config | Firewall tailscale0 port 22 split ownership | — | Open |
| 11 | **LOW** | Duplicate config | `nix.settings.substituters` 3-way split | — | Open |
| 12 | **LOW** | Duplicate config | `nixpkgs.config.allowUnfree` duplicated | — | Open |
| 13 | **LOW** | Cross-domain | `observability/lite.nix` embeds `notify.sh` via builtins.readFile | EXC-002 | Open |

## Tests

- [x] Architecture linter: 5/5 tests passing
- [x] CI integration: GitHub Actions architecture-check job added (non-blocking)
- [x] CI integration: GitLab CI go-lint job added (required gate)
- [ ] Existing 9 NixOS VM tests: PASS (pre-audit baseline)
- [ ] Existing 27 Go test files: PASS (pre-audit baseline)

## Remaining Work

**Next session should:**
1. Resolve remaining HIGH: parameterize hardcoded `prague` in Go code
2. Begin Phase 27: verify existing functionality still works
3. Begin Phase 28: dead code audit
4. Consider making architecture-check blocking once linter passes clean

## Exact Next Action

Resolve the remaining HIGH severity violation: parameterize hardcoded `prague` in Go files. Then begin Phase 27 functionality verification.
