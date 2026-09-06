# Migration Readiness — Elixir/OTP Refactor

**Status**: NOT READY for migration. Acceptance gates documented here; all must pass
before any Elixir/OTP work is scheduled.

---

## Purpose

The repository's stated medium-term goal is an Elixir/OTP migration. This document
defines the *entry criteria*: the repository must first be in a known-good,
self-enforcing, tested baseline. Migration is a **new feature**, not a rescue.

---

## Entry Criteria (all must be green)

### E1: Stabilization baseline

- [x] `ivali doctor` passes all checks (warn-only CPU check acceptable, never gates).
- [x] `ivali verify` passes (architecture linter, duplicate imports, orphan modules,
      security scan).
- [x] `nix flake check --no-build` passes for every host in the flake.
- [x] A fresh, unmodified checkout evaluates: `nix eval .#nixosConfigurations.<host>`.
- [x] Live `/etc/nix/nix.conf` regenerates clean from the flake (no poisoned keys,
      no inherited build timeouts).
- [x] No `TODO` / `FIXME` / `HACK` placeholders in the migration-critical paths.
- [x] CI pipeline fully green on the default branch (GitLab; incl. `go-security`).

### E2: Regression net

- [x] `go test -race -count=1 ./...` passes locally and in CI.
- [x] Every custom script passes `bash -n scripts/*.sh` and `shellcheck --severity=warning`.
- [x] Architecture checker (`cmd/check-architecture`, GitLab `architecture-check` job)
      is enforced in CI.
- [x] At least one regression test exists per critical bug class documented in
      `STABILIZATION.md` (config, runtime, rollback hysteresis, scanner false positives).

### E3: Secrets & security

- [x] All secrets stored exclusively in SOPS-encrypted files under `secrets/`.
- [x] No hardcoded credentials, API keys, or tokens in the tree.
- [x] `gosec` scan clean (or accepted-and-documented findings only).
- [x] **Open**: SOPS break-glass key generation is pending operator decision.
      Migration is blocked until this is decided.

### E4: Runtime & observability

- [x] Runtime secrets mount at `/run/secrets` on boot.
- [x] Systemd service hardening is present (DynamicUser / ProtectSystem) where applicable.
- [x] Health endpoint at `127.0.0.1:9102/health` reports healthy on prague.
- [x] Alertmanager → Telegram routing verified at least once.
- [ ] **Open**: Google Meet / Firefox audio verification (requires real mic hardware).

### E5: Deployment & rollback

- [x] `gitops-reconcile.service` runs every 15 minutes on prague with health gate.
- [x] `scripts/rollback.sh` has hysteresis guards (commit-filtered) — commit `16b17dd`.
- [x] Rollback transitions tested with unit tests for all guard scenarios.
- [x] `ci-deploy.sh` gate parity — now runs the full GitOps gate set
      (flake check, nix eval, HW UUID, Go hash verify, build, health gate,
      rollback); `TimeoutStartSec` raised to 3600s. G3 in STABILIZATION-MATRIX.md.

---

## Definitive Blockers

| # | Blocker | Why it blocks migration | Owner |
|---|---------|-------------------------|-------|
| B1 | SOPS break-glass key not generated | Migration work may need emergency decryption; operator decision required | operator |
| B2 | Google Meet / Firefox audio not checked | Desktop/media is part of the acceptance surface; needs real hardware | operator |
| B3 | Elixir/OTP architecture briefing not authored | No approved target architecture, boundaries, or service contracts | architect |

## Non-Blockers (scheduled)

| # | Item | Where tracked |
|---|------|---------------|
| NB1 | `ci-deploy.sh` gate parity | ✅ done — G3 closed, STABILIZATION-MATRIX.md |
| NB2 | `gosec` blocking status | P4 backlog, G4 |
| NB3 | `flow merge` missing-pipeline handling | bugfix/flow-merge-missing-pipeline |
| NB4 | GitHub Actions parity (fmt / flake / eval) | P4 backlog, G5/G6 |

---

## Migration Ordering (once unblocked)

1. Define target Elixir/OTP architecture (boundaries, contracts, state ownership)
   — mirrors the NixOS domain architecture in AGENTS.md.
2. Keep the Go runtime services running until the Elixir services pass 1:1
   interface tests; dual-run allowed.
3. One runtime service at a time: Telegram → GitOps → Backup → Observability.
4. Maintain syslog/journald structured logging from the first Elixir component.
5. Architecture linter extended to validate Elixir module boundaries before the
   first Elixir service is merged.

---

## Acceptance (Definition of Done for migration entry)

- [ ] All E1–E5 criteria met (open items resolved).
- [ ] All B1–B3 blockers closed (or explicitly waived in writing).
- [ ] Architecture briefing reviewed by lead systems architect (Willis Ivali).
- [ ] CI enforces the NixOS + Elixir boundaries automatically.
- [ ] A fresh host can be provisioned to a green baseline from a clean checkout
      without operator fixes.