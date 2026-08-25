# Architecture Progress

> Tracks the state of the architectural audit and enforcement work.
> Last updated: Session 8 — All architecture linter checks PASS, hardcoded hostnames eliminated, CI failure suppression removed.

---

## Completed

- [x] **Phase 0-18** — Full audit, dependency graph, domain design, state ownership (Sessions 1-3)
- [x] **Phase 19-20** — Architecture manifests (`architecture/domains.yaml`, `dependencies.yaml`, `exceptions.yaml`) with 17 exceptions
- [x] **Phase 21-25** — Architecture linter (7 checks), CI integration, testing (5/5 passing)
- [x] **Phase 26** — Incremental migration: HIGH + MEDIUM severity violations resolved
- [x] **Phase 27-29** — Functionality verified, dead code audited (38 findings), NixOS validation
- [x] **Phase 30-31** — No architectural magic, runtime service contracts (5 interfaces)
- [x] **Phase 32-34** — Documentation complete, all 28 acceptance criteria MET
- [x] **Security** — Hardcoded Grafana credentials removed, SOPS enforced, .gitignore hardened
- [x] **Service Implementations** — 5 concrete types in `internal/services/impl/` (ResticBackup, PrometheusMetrics, SystemHealthChecker, NixOSPlatform, Notification)
- [x] **Service Registry** — Wired in `cmd/ivali/main.go` via `internal/services/container.go`
- [x] **Observability** — Enabled on prague, `docs/observability.md` created
- [x] **golangci-lint v2** — Upgraded to v2.12.2 (CI + config + local binary)
- [x] **Tailscale** — Upgraded to v1.102.2 via nixpkgs flake update
- [x] **Shell Aliases** — 216 aliases rewritten to match all installed CLI tools
- [x] **MEDIUM #6** — `ci-notify.nix` decoupled from `fleet.gitlabRunner.enable` (own option added)
- [x] **MEDIUM #7** — `deployment-health.nix` decoupled from `fleet.gitops` (own `gitopsRepo`/`gitopsBranch` options)
- [x] **MEDIUM #8** — `gitlab-runner.nix` decoupled from `fleet.gitops` (own `gitopsRepo`/`gitopsBranch` options)
- [x] **MEDIUM #9** — `apparmor.nix` bot paths parameterized via `botStateDir`/`botLogDir` variables
- [x] **MEDIUM #10** — Firewall tailscale0 port 22 duplicate removed (SSH only in `ssh/daemon.nix`)
- [x] **LOW #12** — `nixpkgs.allowUnfree` deduplicated (antigravity.nix comment-only, flake-level and system-level are different contexts)
- [x] **P0** — `service_state_ownership` VIOLATION resolved (EXC-011 documents CI/automation shared state)
- [x] **P1** — Hardcoded "prague" eliminated from 4 production files (rebuild.sh, gitlab-runner-reconcile.sh, platform.go, flow.go)
- [x] **P2** — CI failure suppression removed (`|| true` from go test, Makefile lint, GitHub Actions)
- [x] **P3** — Architecture linter improved: removed false-positive undeclared dependency warnings for git/curl/jq (127→8 warnings)
- [x] **P3** — Filesystem boundary exceptions documented (EXC-012 through EXC-017)
- [x] **P4** — `/var/lib/gitops` ownership formalized in architecture manifests
- [x] **Hardware domain** — New `hardware/` domain with USB power management (usb-power.nix)
- [x] **Boot fixes** — TPM modules blacklisted, serial ports disabled (~9min boot → ~3min)
- [x] **GRUB bootloader** — Switched from systemd-boot to GRUB with NixOS snowflake theme
- [x] **Audio fixes** — ALSA mixer init, WirePlumber rules for consistent volume on ALC236
- [x] **Commit authorship** — Rule added to AGENTS.md, ENGINEERING.md, CONTRIBUTING.md

## Architecture Linter Status

```
✓ forbidden_imports
✓ circular_dependencies
✓ filesystem_boundaries
✓ duplicate_ownership
✓ declared_dependencies
✓ internal_api_boundaries
✓ service_state_ownership
```

**All 7 checks PASS.**

## Known Violations (Remaining LOW)

| # | Severity | Category | Description | Status |
|---|----------|----------|-------------|--------|
| 11 | **LOW** | Duplicate config | `nix.settings.substituters` 3-way split across `system/nix.nix`, `caching/default.nix`, `cache/default.nix` | Open — acceptable |

## Tests

- [x] Architecture linter: 7/7 checks PASS
- [x] Go tests: all passing
- [x] golangci-lint v2: 0 issues
- [x] NixOS evaluation: all 3 hosts evaluate, no errors
- [x] Shell syntax: all scripts parse cleanly
- [x] Nix formatting: 0 files need reformatting
- [x] CI: GitHub Actions + GitLab CI configured (golangci-lint v2.12.2)

## Verification Gate Results

| Gate | Status |
|------|--------|
| `nix fmt -- --check .` | PASS |
| `go build ./...` | PASS |
| `go vet ./...` | PASS |
| `go test ./...` | PASS |
| `bash -n scripts/*.sh` | PASS |
| `nix eval .#nixosConfigurations.prague` | PASS |
| `nix eval .#nixosConfigurations.testvm` | PASS |
| `nix eval .#nixosConfigurations.tuscany` | PASS |
| Architecture linter (7 checks) | PASS |

## Exact Next Action

Run `sudo nixos-rebuild switch --flake ~/nixos-infrastructure#prague` to apply all changes (dynamic hostname detection, architecture linter improvements, CI enforcement).
