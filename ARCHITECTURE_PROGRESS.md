# Architecture Progress

> Tracks the state of the architectural audit and enforcement work.
> Last updated: Session 7 — All MEDIUM violations resolved. System ready for rebuild.

---

## Completed

- [x] **Phase 0-18** — Full audit, dependency graph, domain design, state ownership (Sessions 1-3)
- [x] **Phase 19-20** — Architecture manifests (`architecture/domains.yaml`, `dependencies.yaml`, `exceptions.yaml`) with 10 exceptions
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

## Known Violations (Remaining LOW)

| # | Severity | Category | Description | Status |
|---|----------|----------|-------------|--------|
| 11 | **LOW** | Duplicate config | `nix.settings.substituters` 3-way split across `system/nix.nix`, `caching/default.nix`, `cache/default.nix` | Open — acceptable |
| 13 | **LOW** | Cross-domain | `observability/lite.nix` embeds `notify.sh` via builtins.readFile (EXC-002) | Open — documented exception |

## Tests

- [x] Architecture linter: 5/5 tests passing
- [x] Go tests: all passing
- [x] golangci-lint v2: 0 issues
- [x] NixOS evaluation: all 3 hosts evaluate, no errors
- [x] CI: GitHub Actions + GitLab CI configured (golangci-lint v2.12.2)

## Exact Next Action

Run `sudo nixos-rebuild switch --flake ~/nixos-infrastructure#prague` to apply all changes (Tailscale 1.102.2, alias rewrite, apparmor parameterization).
