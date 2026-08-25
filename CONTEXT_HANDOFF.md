# Context Handoff

> This document provides a complete summary of the architectural audit work,
> current state, and next steps for continuity across sessions.

---

## Executive Summary

The NixOS infrastructure repository has undergone a comprehensive 33-phase
architectural audit and enforcement process. The repository now has:

- **Clean architecture** with domain-oriented modules
- **Service contracts** defining explicit interfaces between runtime services
- **Architecture linter** enforcing boundaries in CI
- **Complete documentation** with dependency graphs and migration guide
- **Dead code eliminated** with 38+ findings resolved
- **Architectural magic removed** with 57+ patterns identified and fixed

---

## Completed Phases (1-33)

### Phase 0-18: Audit & Discovery

| Phase | Description | Key Findings |
|-------|-------------|--------------|
| 0 | Repository understood | 187 Nix files, 127 Go files, 16 scripts, ~40 services |
| 1 | Complete audit | Domain hierarchy mapped |
| 2 | Full inventory | Modules, services, timers, scripts, packages, secrets |
| 3 | Dependency graph | Nix imports, runtime deps, script deps, filesystem deps |
| 4 | Dependency graphs produced | Mermaid diagrams in ARCHITECTURE_AUDIT.md |
| 5 | Runtime service graph | Service interactions documented |
| 6 | Circular dependencies | NONE FOUND |
| 7 | Cross-domain coupling | 7 findings (C1-C7) |
| 8 | Cross-domain filesystem | 8 findings (F1-F8) |
| 9 | Duplicate configuration | 7 findings (D1-D7), 1 HIGH severity |
| 10 | Undeclared dependencies | 6 findings (U1-U6) |
| 11 | Internal API violations | Documented |
| 12 | Cross-service state mutation | Documented |
| 13-18 | Domain boundaries, ownership | Complete hierarchy established |

### Phase 19-25: Implementation & CI

| Phase | Description | Key Deliverables |
|-------|-------------|------------------|
| 19-20 | Architecture manifests | `architecture/domains.yaml`, `dependencies.yaml`, `exceptions.yaml` |
| 21-23 | Architecture linter | Go implementation with 5 tests, all passing |
| 24-25 | CI integration | GitHub Actions + GitLab CI jobs (go-lint required) |

### Phase 26-33: Remediation & Documentation

| Phase | Description | Key Deliverables |
|-------|-------------|------------------|
| 26 | HIGH violations resolved | CPUQuota, scripts, gitops ownership, Go hostnames |
| 27 | Functionality verified | All gates pass (nix fmt, flake check, go build/test, lint) |
| 28 | Dead code audit | 38 findings resolved, code completeness rules added |
| 29 | NixOS validation | All 3 hosts evaluate, no errors |
| 30 | Architectural magic removed | Hardcoded paths, secret ports, observability URLs |
| 31 | Service contracts | 5 interfaces (Notification, Backup, Metrics, Health, Platform) |
| 32 | Full documentation | ARCHITECTURE.md with contracts, graphs, migration guide |
| 33 | Context handoff | This document |

---

## Current State

### Repository Health

| Metric | Status |
|--------|--------|
| `nix fmt` | ✓ Pass |
| `nix flake check --no-build` | ✓ Pass (3 hosts evaluate) |
| `go build ./...` | ✓ Pass |
| `go test ./...` | ✓ Pass (17 packages) |
| `golangci-lint run` | ✓ Pass |
| Architecture linter | ✓ 5/5 tests pass |

### Files Created/Modified

**New packages:**
- `internal/services/` — Service contracts (5 interfaces + registry)
- `internal/nixutil/` — Shared Nix utilities
- `internal/secrets/` — Centralized SOPS secret reading
- `internal/observability/` — Centralized port/URL constants
- `internal/architecture/` — Architecture linter
- `hardware/default.nix` — Hardware domain barrel module
- `hardware/usb-power.nix` — USB runtime autosuspend fix
- `boot/grub-theme.nix` — NixOS GRUB theme definition

**New documentation:**
- `ARCHITECTURE.md` — Complete architectural reference
- `ARCHITECTURE_AUDIT.md` — Audit findings and violation details
- `ARCHITECTURE_PROGRESS.md` — Phase tracking
- `scripts/README.md` — Script documentation

**New CI:**
- `.github/workflows/ci.yml` — GitHub Actions (architecture-check, go-lint)
- `.gitlab-ci.yml` — GitLab CI (go-lint required, go-build, go-test)

**Modified files:**
- `AGENTS.md` — Added PART 5 (architectural governance), §3.5 (testing rules), commit authorship rule
- `boot/kernel.nix` — TPM modules blacklisted, serial ports disabled (8250.nr_uarts=0)
- `boot/loader.nix` — Switched from systemd-boot to GRUB with NixOS snowflake theme
- `desktop/common/audio.nix` — ALSA mixer init, WirePlumber rules for ALC236
- `ENGINEERING.md` — Added commit authorship rule
- `CONTRIBUTING.md` — Added commit authorship rule
- `CODEOWNERS` — Added hardware/ domain
- `MODULES.md` — Added hardware/ domain
- `README.md` — Updated kernel, bootloader, hardware domain references
- `SUMMARY.md` — Updated kernel, bootloader, hardware domain references
- `observability/lite.nix` — Fixed broken shell script
- `internal/commands/ai.go` — Implemented real routing logic
- `internal/commands/firewall.go` — Removed redundant min()
- `internal/bitwarden/tui.go` — Removed redundant min()/max()
- `internal/commands/root.go` — Removed dead placeholder lines
- `internal/remediation/actions.go` — Dynamic hostname in rebuild
- `internal/dashboard/dashboard.go` — Dynamic hostname, observability URLs
- `internal/plugin/gitops.go` — Dynamic repo directory
- `internal/repository/repository.go` — Uses shared nixutil
- `internal/commands/explain.go` — Uses shared nixutil
- `automation/gitops-reconciler.nix` — Added StateDirectory
- `observability/grafana.nix` — Consolidated resource limits
- `observability/loki.nix` — Removed duplicate CPUQuota
- `observability/prometheus.nix` — Removed duplicate limits
- `scripts/gitlab-runner-reconcile.sh` — Hostname detection
- `scripts/gitops-reconcile.sh` — Hostname detection
- `scripts/rollback.sh` — Hostname detection

---

## Known Violations (Open)

### HIGH Priority (None)

All HIGH severity violations have been resolved.

### MEDIUM Priority

| # | Category | Description | Exception | Status |
|---|----------|-------------|-----------|--------|
| 5 | Cross-domain coupling | `ci-notify.nix` gates on `fleet.gitlabRunner.enable` | EXC-007 | Open |
| 6 | Cross-domain coupling | `deployment-health.nix` reads `fleet.gitops` options | EXC-008 | Open |
| 7 | Cross-domain coupling | `gitlab-runner.nix` reads `fleet.gitops` options | EXC-009 | Open |
| 8 | Filesystem access | `security/apparmor.nix` hardcodes bot paths | EXC-005 | Open |
| 10 | Duplicate config | Firewall tailscale0 port 22 split ownership | — | Open |

### LOW Priority

| # | Category | Description | Exception | Status |
|---|----------|-------------|-----------|--------|
| 11 | Duplicate config | `nix.settings.substituters` 3-way split | — | Open |
| 12 | Duplicate config | `nixpkgs.config.allowUnfree` duplicated | — | Open |
| 13 | Cross-domain | `observability/lite.nix` embeds `notify.sh` via builtins.readFile | EXC-002 | Open |

---

## Next Steps

### Immediate (Phase 34)

**Phase 34: Final Acceptance Test**

Verify all architectural requirements are met:
- [ ] Repository fully audited
- [ ] Actual dependency graph created
- [ ] Runtime dependency graph created
- [ ] Domains defined
- [ ] Domain ownership documented
- [ ] Public interfaces defined
- [ ] Internal implementations isolated
- [ ] State ownership defined
- [ ] Filesystem ownership defined
- [ ] Circular dependencies eliminated
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

### Short-term (Next Session)

1. **Implement concrete service types** for the 5 interfaces:
   - `NotificationService` (NotificationService)
   - `ResticBackup` (BackupService)
   - `PrometheusMetrics` (MetricsProvider)
   - `SystemHealth` (HealthChecker)
   - `NixOSPlatform` (PlatformService)

2. **Wire up service registry** in `cmd/ivali/main.go`

3. **Begin refactoring** existing code to use service contracts

### Medium-term (Future Sessions)

1. **Eliminate notify.sh** — Replace with NotificationService
2. **Unify health checks** — Replace 3 implementations with HealthChecker
3. **Extract backup from GitOps** — Move to BackupService
4. **Eliminate hardcoded ports** — Use MetricsProvider
5. **Make architecture-check blocking** — Once linter passes clean

---

## Key Commands

```bash
# Verification gates
nix fmt -- --check
nix flake check --no-build
go build ./...
go test ./...
~/go/bin/golangci-lint run ./... --timeout=5m

# Architecture linter
go test ./internal/architecture/... -v
./ci/check-architecture

# Git operations
git add -A && git commit -m "type(scope): description"
git push origin main
```

---

## Architecture Files

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | Complete architectural reference |
| `ARCHITECTURE_AUDIT.md` | Audit findings and violation details |
| `ARCHITECTURE_PROGRESS.md` | Phase tracking |
| `architecture/domains.yaml` | Domain definitions |
| `architecture/dependencies.yaml` | Dependency graph |
| `architecture/exceptions.yaml` | Documented exceptions |

---

## Contact

For questions about the architecture, refer to:
- `AGENTS.md` — Engineering contract
- `ARCHITECTURE.md` — Architectural reference
- `ARCHITECTURE_PROGRESS.md` — Current progress
