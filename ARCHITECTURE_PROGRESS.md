# Architecture Progress

> Tracks the state of the architectural audit and enforcement work.
> Last updated: Session 2 — linter implemented, CI integrated, Phases 19-25 complete.

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
- [x] **AGENTS.md** — Architectural role added as PART 5
- [x] **Firefox** — Launcher rail unhidden + Gruvbox-themed

## In Progress

- [ ] **Phase 26** — Incremental migration (resolve known violations)

## Not Started

- [ ] **Phase 27** — Preserve existing functionality verification
- [ ] **Phase 28** — Dead code audit (preliminary: none found)
- [ ] **Phase 29** — NixOS validation (nix flake check)
- [ ] **Phase 30** — No architectural magic verification
- [ ] **Phase 31** — Runtime service contracts
- [ ] **Phase 32** — Full documentation
- [ ] **Phase 33** — Context handoff document
- [ ] **Phase 34** — Final acceptance test

## Linter Output (current state)

```
  ✓ forbidden_imports         (all pass with EXC-010)
  ✓ circular_dependencies     (no cycles detected)
  ✗ filesystem_boundaries     (3 QUESTIONABLE — known, documented)
  ✓ duplicate_ownership       (no conflicts)
  ✓ declared_dependencies     (no false positives after tuning)
  ✗ internal_api_boundaries   (1 VIOLATION — core.boot→shared.theme, exempted via EXC-010)
  ✗ service_state_ownership   (1 VIOLATION — ci→gitops, documented in EXC-003)
```

The 2 remaining QUESTIONABLE filesystem + 1 VIOLATION are all documented in `architecture/exceptions.yaml` as `needs_resolution`. These will be resolved during Phase 26 migration.

## Known Violations (Priority Order)

| # | Severity | Category | Description | Exception | Status |
|---|----------|----------|-------------|-----------|--------|
| 1 | **HIGH** | Duplicate config | `loki` CPUQuota conflict: 15% vs 10% | — | Open |
| 2 | **HIGH** | Hardcoded hostname | 5 shell scripts hardcode `HOST="prague"` | — | Open |
| 3 | **HIGH** | Hardcoded hostname | 4 Go files hardcode `prague` deploy target | — | Open |
| 4 | **HIGH** | State ownership | `/var/lib/gitops` has no formal owner | EXC-003/004 | Open |
| 5 | **MEDIUM** | Cross-domain coupling | `ci-notify.nix` gates on `fleet.gitlabRunner.enable` | EXC-007 | Open |
| 6 | **MEDIUM** | Cross-domain coupling | `deployment-health.nix` reads `fleet.gitops` options | EXC-008 | Open |
| 7 | **MEDIUM** | Cross-domain coupling | `gitlab-runner.nix` reads `fleet.gitops` options | EXC-009 | Open |
| 8 | **MEDIUM** | Filesystem access | `security/apparmor.nix` hardcodes bot paths | EXC-005 | Open |
| 9 | **MEDIUM** | Duplicate config | `prometheus`/`node-exporter` resource limits duplicated | — | Open |
| 10 | **MEDIUM** | Duplicate config | Firewall tailscale0 port 22 split ownership | — | Open |
| 11 | **LOW** | Duplicate config | `nix.settings.substituters` 3-way split | — | Open |
| 12 | **LOW** | Duplicate config | `nixpkgs.config.allowUnfree` duplicated | — | Open |
| 13 | **LOW** | Cross-domain | `observability/lite.nix` embeds `notify.sh` via builtins.readFile | EXC-002 | Open |

## Tests

- [x] Architecture linter: 5/5 tests passing
- [x] CI integration: GitHub Actions architecture-check job added (non-blocking)
- [ ] Existing 9 NixOS VM tests: PASS (pre-audit baseline)
- [ ] Existing 27 Go test files: PASS (pre-audit baseline)

## Remaining Work

**Next session should:**
1. Begin Phase 26 migration: resolve HIGH severity violations
2. Give CI its own gitops worktree (`/var/lib/ci`) to resolve EXC-003/EXC-004
3. Make architecture-check blocking once linter passes clean

## Exact Next Action

Begin Phase 26 incremental migration. Start with the HIGH severity violations:
1. Fix `loki` CPUQuota conflict (pick one value, remove duplicate)
2. Parameterize hardcoded hostnames in scripts and Go code
3. Give CI domain its own state directory to resolve gitops ownership conflict
