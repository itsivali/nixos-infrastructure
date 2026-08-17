# Architecture Progress

> Tracks the state of the architectural audit and enforcement work.
> Last updated: Session 1 — initial audit complete.

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
- [x] **AGENTS.md** — Architectural role added as PART 5
- [x] **Firefox** — Launcher rail unhidden + Gruvbox-themed

## In Progress

- [ ] **Phase 19** — Architecture manifest (domains.yaml, dependencies.yaml, exceptions.yaml)
- [ ] **Phase 20** — Architecture exceptions document

## Not Started

- [ ] **Phase 21** — Architecture linter implementation (Go, 7 checks)
- [ ] **Phase 22** — Local architecture command (ci/check-architecture)
- [ ] **Phase 23** — Architecture linter tests
- [ ] **Phase 24** — CI integration
- [ ] **Phase 25** — CI enforcement active
- [ ] **Phase 26** — Incremental migration
- [ ] **Phase 27** — Preserve existing functionality verification
- [ ] **Phase 28** — Dead code audit (preliminary: none found)
- [ ] **Phase 29** — NixOS validation (nix flake check)
- [ ] **Phase 30** — No architectural magic verification
- [ ] **Phase 31** — Runtime service contracts
- [ ] **Phase 32** — Full documentation
- [ ] **Phase 33** — Context handoff document
- [ ] **Phase 34** — Final acceptance test

## Known Violations (Priority Order)

| # | Severity | Category | Description | Status |
|---|----------|----------|-------------|--------|
| 1 | **HIGH** | Duplicate config | `loki` CPUQuota conflict: 15% vs 10% | Open |
| 2 | **HIGH** | Hardcoded hostname | 5 shell scripts hardcode `HOST="prague"` | Open |
| 3 | **HIGH** | Hardcoded hostname | 4 Go files hardcode `prague` deploy target | Open |
| 4 | **HIGH** | State ownership | `/var/lib/gitops` has no formal owner | Open |
| 5 | **MEDIUM** | Cross-domain coupling | `ci-notify.nix` gates on `fleet.gitlabRunner.enable` | Open |
| 6 | **MEDIUM** | Cross-domain coupling | `deployment-health.nix` reads `fleet.gitops` options | Open |
| 7 | **MEDIUM** | Cross-domain coupling | `gitlab-runner.nix` reads `fleet.gitops` options | Open |
| 8 | **MEDIUM** | Filesystem access | `security/apparmor.nix` hardcodes bot paths | Open |
| 9 | **MEDIUM** | Duplicate config | `prometheus`/`node-exporter` resource limits duplicated | Open |
| 10 | **MEDIUM** | Duplicate config | Firewall tailscale0 port 22 split ownership | Open |
| 11 | **MEDIUM** | Undeclared deps | Scripts use `ivali` CLI without declaring it | Open |
| 12 | **LOW** | Duplicate config | `nix.settings.substituters` 3-way split | Open |
| 13 | **LOW** | Duplicate config | `nixpkgs.config.allowUnfree` duplicated | Open |
| 14 | **LOW** | Cross-domain | `observability/lite.nix` embeds `notify.sh` via builtins.readFile | Open |

## Tests

- [ ] Architecture linter: not yet implemented
- [ ] CI integration: not yet implemented
- [ ] Existing 9 NixOS VM tests: PASS (pre-audit baseline)
- [ ] Existing 27 Go test files: PASS (pre-audit baseline)

## Remaining Work

**Next session should:**
1. Create `architecture/domains.yaml`, `architecture/dependencies.yaml`, `architecture/exceptions.yaml` (Phase 19-20)
2. Begin architecture linter implementation in Go (Phase 21)
3. Start fixing HIGH severity violations (loki CPUQuota, hardcoded hostnames, gitops ownership)

## Exact Next Action

Create `architecture/` directory with the three manifest files (domains.yaml, dependencies.yaml, exceptions.yaml), then begin implementing the Go architecture linter in `internal/architecture/`.
