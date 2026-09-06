# Stabilization Matrix — Gate Coverage & Known Gaps

**Purpose**: Record exactly which verification gates exist, what each covers,
and where the gaps remain. Used as a contract for CI, deployment, and
operational workflows.

---

## Local Gate Coverage

| Gate | `flow validate` | `flow run` | `flow quick` | `ivali verify` | `ivali doctor` |
|------|:-:|:-:|:-:|:-:|:-:|
| `nix fmt -- --check .` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `shellcheck --severity=warning` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `go build ./...` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `go vet ./...` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `go test -race -count=1 ./...` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `gosec -exclude-generated ./...` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `nix flake check --no-build` | ✅ | ❌ | ❌ | ✅ | ✅ |
| `nix eval .#nixosConfigurations.<host>` | ✅ (--host) | ❌ | ❌ | ❌ | ❌ |
| Architecture linter | ❌ | ❌ | ❌ | ✅ | ✅ |
| `deadnix` / `statix` | ❌ | ❌ | ❌ | ❌ | ✅ |
| Duplicate imports check | ❌ | ❌ | ❌ | ✅ | ✅ |
| Orphan modules check | ❌ | ❌ | ❌ | ✅ | ✅ |
| Security scan | ❌ | ❌ | ❌ | ✅ | ✅ |
| System health | ❌ | ❌ | ❌ | ❌ | ✅ |

## CI Gate Coverage

| Gate | GitLab CI | GitHub Actions |
|------|:-:|:-:|
| `nix fmt -- --check .` | ✅ | ❌ |
| `shellcheck --severity=warning` | ✅ | ✅ |
| `golangci-lint run` | ✅ | ✅ |
| Architecture linter | ✅ | ❌ |
| `go build ./...` | ✅ | ❌ (via golangci) |
| `go test -race -count=1 ./...` | ✅ | ✅ |
| `gosec -exclude-generated ./...` | ✅ (allow_failure) | ✅ (continue-on-error) |
| `nix flake check --no-build` | ✅ | ❌ |
| `nix eval .#nixosConfigurations.prague` | ✅ | ❌ |

## Deployment Gate Coverage

| Gate | `gitops-reconcile.sh` | `rebuild.sh` | `ci-deploy.sh` |
|------|:-:|:-:|:-:|
| Lock acquisition | ✅ | ❌ | ✅ (shared) |
| Dirty-tree guard | ✅ | ❌ | ✅ |
| `git fetch` | ✅ | ✅ | ❌ |
| `git rebase` | ❌ (ff-only pull) | ✅ | ❌ |
| Repository integrity (`git fsck`) | ✅ | ❌ | ❌ |
| Hardware UUID check | ✅ | ✅ | ✅ |
| Go vendor hash verify | ✅ | ✅ (conditional) | ✅ |
| `nix flake check` | ✅ | ✅ | ✅ |
| `nix eval` | ❌ | ✅ | ✅ |
| `nix build` | ✅ | ❌ (rebuild does build+activate) | ✅ |
| `nixos-rebuild switch` | ✅ | ✅ | ✅ |
| Health gate (post-deploy) | ✅ | ❌ | ✅ |
| Rollback on failure | ✅ | ❌ | ✅ |

## Combined View

| Scenario | fmt | shell | go build | go vet | go test | gosec | flake check | nix eval | arch | HW UUID | health |
|----------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Full local (`flow validate`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| CI push (GitLab) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| CI push (GitHub) | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| GitOps deploy | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ |
| Manual rebuild | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| `flow quick` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `flow run` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

## Known Gaps

### G1: `flow quick` skips nix fmt, shellcheck, flake check, gosec

**Risk**: code passing `quick` may fail CI.
**Status**: ✅ **FIXED (6 September 2026)** — `flow quick` now runs all seven
local gates (`nix fmt`, `shellcheck`, `go build`, `go vet`, `go test -race`,
`gosec`, `nix flake check`). Only host `nix eval` remains opt-in via
`flow validate --host`.

### G2: `flow run` skips shellcheck, flake check, gosec

**Risk**: same as G1.
**Status**: ✅ **FIXED (6 September 2026)** — `flow run` now runs the same full
seven-gate suite as `flow quick` before committing and pushing.

### G3: `ci-deploy.sh` has fewer gates than `gitops-reconcile.sh`

**Risk**: CI-triggered deploy skips flake check, nix eval, Go hash verify.
**Status**: ✅ **FIXED (6 September 2026)** — `ci-deploy.sh` now mirrors the full
GitOps gate set: dirty-tree guard, flake check, nix eval, HW UUID, Go hash
verify, build, health gate, rollback on failure. `ci/ci-deploy.nix` raised
`TimeoutStartSec` from 300s to 3600s so the gate flow cannot be killed mid-rebuild.

### G4: `gosec` is `allow_failure` / `continue-on-error` in CI

**Risk**: security scan failures do not block merges.
**Mitigation**: tracked in P4 backlog; remove `allow_failure` once scan
is fully deterministic.

### G5: Architecture linter only in GitLab CI

**Risk**: no local architecture validation unless `ivali verify` is run.
**Mitigation**: run `ivali verify` locally before pushing.

### G6: `flow merge` treats missing pipeline as passed

**Risk**: MR may merge before CI starts.
**Mitigation**: check pipeline existence before treating as passed (tracked
in bugfix/flow-merge-missing-pipeline).

---

## P4: CI Deploy-Gate Alignment

**Objective**: bring `ci-deploy.sh` to parity with `gitops-reconcile.sh`.

**Status**: ✅ **DONE (6 September 2026)** — `scripts/ci-deploy.sh` implements
the full gate set:

1. `nix flake check --no-build` before build.
2. `nix eval` before switch.
3. Go vendor hash verification.
4. Post-deploy health gate.
5. Rollback on failure.

`ci/ci-deploy.nix` sets `TimeoutStartSec = "3600s"` (was 300s) so a full
build + switch + health gate on this 2-core box is not killed mid-run.

---

## Post-Fix Verification (5 September 2026)

All of the following passed on prague with the fixed generation (`26.11.20260829.d2f6794`):

- `ivali doctor` — 51/52 (CPU warn-only, exit 0)
- `ivali verify` — all checks passed
- `nix fmt -- --check .` — 0/219 reformatted
- `nix flake check --no-build` — all checks passed
- `nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name` — evaluates
- `go build ./...`, `go vet ./...` — clean
- `go test -race -count=1 ./...` — all pass
- `bash -n scripts/*.sh` — clean
- `nix run nixpkgs#gosec -- --version` — 2.29.0, no override flags needed
- Live `/etc/nix/nix.conf` — no attic poison, no `timeout = 60`
