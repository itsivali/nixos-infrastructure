# Stabilization — Acceptance Record

**Milestone**: nixos-infrastructure stabilization (P0→P1)
**Date**: 5 September 2026
**Host**: prague (AMD A6-9225, 2 cores, 4 GiB, NixOS 26.11)

---

## Status

```
P0  Foundation          COMPLETE   (commits 277481d → 9aa4db5)
P1  Operations          COMPLETE   (commit 16b17dd + MR #28)
P2  Rollback hysteresis COMPLETE   (commit 16b17dd)
P3  Doctor runtime      COMPLETE   (commit 16b17dd)
P4  CI deploy-gate      BACKLOG    (gap documented in STABILIZATION-MATRIX.md)
P5  Elixir/OTP refactor  NOT STARTED (blocked on MIGRATION-READINESS.md)
```

**Known open items (operator-only)**:
- SOPS break-glass key generation — pending operator decision on storage location + real hardware.
- Google Meet / Firefox audio verification — requires real microphone hardware.

---

## What Was Fixed

### P0: Attic cache poisoning (commit e548a64)

**Bug classification**: configuration + runtime

`cache/default.nix` set `trustedKey = "${host}-1:${cfg.publicKey}"` with empty `publicKey`.
This produced a corrupted `trusted-public-keys = cache.codlet-trench.ts.net-1:` entry in
every generation's `/etc/nix/nix.conf`. Every uncached nix fetch failed with
"corrupt key", including `nix run` from CI jobs.

The `attic-server` unit invoked an invalid `atticd serve --listen ... --store` (modern
`atticd` has no `serve` subcommand; it uses `--config`, `--listen`, `--mode`). The unit
crash-looped (start-limit-hit).

**Fix**: `cache/default.nix` config guarded with `lib.mkIf (cfg.enable && cfg.publicKey != "")`
(fail-safe: empty key = zero cache wiring). Removed the `server` options and broken
`attic-server` unit. Updated `laptop.nix`, `DOCS.md`, `scripts/cache-stats.sh` to match.

**Root cause**: the broken `attic-server` unit masked the underlying key; the repo
defect was present since commit `6953253` (added cache feature) and survived through
`0dda834` (which only renamed `attic` → `atticd`).

### P0: Nix build timeout = 60 (commit 773477f)

**Bug classification**: configuration

`system/nix.nix` set `nix.settings.timeout = 60`, capping every derivation build at 60
seconds. The local Go tools (`ivali`, `bw-tui`) routinely exceed that on the 2-core
A6-9225, so `nixos-rebuild switch` failed nondeterministically. Nix's default is
unlimited (0).

**Fix**: removed `timeout = 60` entirely; documented why in a block comment.

### P1: Operations diagnostics (commit 16b17dd)

Added `runtime_checks.go` + `_test.go` to `internal/commands/` covering: SOPS age-key
presence, `/run/secrets` mount, restic binary, NixOS generation health, disk space,
and service states. `doctor.go` and `scanner.go` updated. `vali flow push` fixed for
fresh branches (commit `37baae7`).

### P1: Rollback hysteresis (commit 16b17dd)

Added anti-loop guards to `scripts/rollback.sh` (commit-count delta cap, consecutive
rollback guard, last-rollback timestamp). All scenarios unit-tested.

### P1: SOPS web-ui secret (commit 16b17dd)

`secrets/web-ui.yaml` provisioned with `sops.secrets.web-ui.nix` module wiring.
Operational immediately.

---

## Validation on Real Hardware

| Gate | Status | Notes |
|------|--------|-------|
| `ivali doctor` | 51/52 | CPU check warns (208% of 2 cores); never gates; exit code = 0 |
| `ivali verify` | passed | all checks clean |
| `nix fmt -- --check .` | 0/219 reformatted | all nix files formatted |
| `nix flake check --no-build` | passed | flake schema valid |
| `nix eval .#nixosConfigurations.prague` | `nixos-system-prague-26.11.20260829.d2f6794` | configuration evaluates cleanly |
| Go build | clean | `go build ./...`, `go vet ./...` |
| Go tests | all pass | `go test -race -count=1 ./...` (exit 0) |
| Shell syntax | clean | `bash -n scripts/*.sh` |
| `nix run nixpkgs#gosec` | 2.29.0 (from cache.nixos.org) | works with no overrides after nix.conf heal |

**Live `/etc/nix/nix.conf` verified** after prague rebuild (per operator authorization):
no `cache.codlet-trench.ts.net` entries, no `timeout = 60`, clean substituters from
`cache.nixos.org` only.

---

## Deployment Sequence

1. `nixos-rebuild switch --flake .#prague` (required root via `sudo`, operator-driven).
2. Live nix.conf regenerated clean on this rebuild — poisoned entries removed.
3. CI runner (on prague) now reads a clean nix.conf; `go-security` job passes.
4. MR #28 merged (`9aa4db5`), GitOps picks up main.

---

## Files Changed

| File | Purpose |
|------|---------|
| `cache/default.nix` | Consumer-only fail-safe guard, server half removed |
| `system/nix.nix` | 60s build timeout removed |
| `internal/commands/runtime_checks.go` + `_test.go` | SOPS / secrets / disk / service probes |
| `internal/commands/doctor.go` + `_test.go` | Warn-only vs fail-only semantics |
| `internal/security/scanner.go` + `_test.go` | False positive on cached UUID |
| `internal/commands/flow.go` + `_test.go` | Fresh-branch push fix |
| `scripts/rollback.sh` | Hysteresis anti-loop guards |
| `scripts/audio-diagnostic.sh` | Mic / speaker / codec diagnostics |
| `secrets/web-ui.yaml` | SOPS-encrypted web-ui secret |
| `system/nix.nix` | timeout = 60 removed |
| `lib/host-templates/laptop.nix` | `fleet.cache` set dormant |
| `scripts/cache-stats.sh` | Removed broken attic-server stats |
| `DOCS.md` | Updated attic section to reflect consumer-only |

---

## What Remains

| Item | Owner | Status | Notes |
|------|-------|--------|-------|
| SOPS break-glass key | operator | **pending** | Needs decision: storage location + real hardware |
| Google Meet / Firefox audio | operator | **pending** | Requires real microphone hardware |
| P4: CI deploy-gate alignment | backlog | **not started** | `ci-deploy.sh` has fewer gates than `gitops-reconcile.sh` |
| P5: Elixir/OTP refactor | blocked | **not started** | Blocked on MIGRATION-READINESS.md |
| `docs/STABILIZATION-MATRIX.md` | this PR | in progress | CI / gate coverage gaps (see separate file) |
| `docs/MIGRATION-READINESS.md` | this PR | in progress | Acceptance for Elixir work (see separate file) |
