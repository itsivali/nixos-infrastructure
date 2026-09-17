# Fix GitOps Reconciler SSH URL Consistency

## Context

Branch `bugfix/fix-gitops-reconciler-ssh-url` contains 2 commits that fix the
`fleet.gitops.repo` URL from HTTPS to SSH across the reconciler path. These
commits are unmerged and the working tree is clean.

**Branch state:**
- Current branch: `bugfix/fix-gitops-reconciler-ssh-url`
- HEAD: `2eda108` — ahead of merge-base with `main`
- Working tree: clean
- 2 commits:
  - `9386517` — `lib/host-templates/laptop.nix`: HTTPS → SSH URL
  - `2eda108` — `automation/common.nix` + `tests/automation-smoke.nix`: HTTPS → SSH URL

**Root cause:** The reconciler runs as the unprivileged `ivali` user and authenticates to GitLab via a passphrase-less Ed25519 deploy key (`/home/ivali/.ssh/id_ed25519`). HTTPS URLs require interactive username/password prompts; SSH URLs use the configured key automatically.

**Why unfinished:** The two commits fix the primary `fleet.gitops.repo` values, but one remaining `example` attribute in `automation/options.nix:40` still shows the old HTTPS URL, creating an inconsistency between documented examples and actual defaults.

## Document Map

| Document | Relevance |
|----------|-----------|
| `AGENTS.md` | AI operating contract — TDD, ivali flow, verification gates |
| `IVALi_FLOW.md` | Git workflow — all changes must use `ivali flow` |
| `CONTEXT_HANDOFF.md` | Records KDE migration work (separate branch, already merged to main) |
| `ARCHITECTURE_AUDIT.md` | Configuration ownership rules |
| `ARCHITECTURE_PROGRESS.md` | LOW-11: configuration consolidation |

## Remaining Work

### 1. Update `automation/options.nix` example for consistency

**File:** `automation/options.nix:40`
**Current:** `example = "https://gitlab.com/willisivali/nixos-infrastructure";`
**Target:** `example = "git@gitlab.com:willisivali/nixos-infrastructure.git";`

**Rationale:** The `example` attribute documents the expected format for `fleet.gitops.repo`. The actual defaults in `automation/common.nix`, `lib/host-templates/laptop.nix`, and `tests/automation-smoke.nix` now use SSH URLs. Leaving the example as HTTPS misleads users and creates a documentation/implementation mismatch (AGENTS.md §10: Planning Must Resolve Documentation Conflicts).

**Risk:** Very low — this is a documentation string only, no runtime behavior change.

### 2. Run verification gates

```bash
nix fmt -- --check .
go build ./...
go vet ./...
go test -race -count=1 ./...
bash -n scripts/*.sh
nix flake check --no-build
nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name
nix eval .#nixosConfigurations.tuscany.config.system.build.toplevel.name
```

**Applicable tests (Nix-focused; no Go code changes):**
- `nix fmt -- --check .` — formatting
- `nix flake check --no-build` — flake evaluation
- `nix eval` for prague and tuscany — host evaluation
- `bash -n scripts/gitops-reconcile.sh` — shell syntax (touched via indirect config)

**Note:** No Go code is changed in this fix, so Go build/vet/test are included for completeness per the verification contract but are expected to pass unchanged.

### 3. Commit via `ivali flow`

```bash
ivali flow commit
```

Commit message format (per `IVALi_FLOW.md`):
```
fix(automation): update gitops repo example to SSH URL
```

Author: `Willis Ivali <itsivali@outlook.com>` (mandatory per AGENTS.md §16)

### 4. Push and create MR

```bash
ivali flow push
ivali flow mr
```

## Not Changing

| File | URL | Reason |
|------|-----|--------|
| `flake.nix:70` | `https://gitlab.com/willisivali/nixos-infrastructure` | This is `gitlabUrl` for `system.autoUpgrade.flake` (Nix flake fetching), NOT `fleet.gitops.repo`. Different concern — Nix auto-upgrade uses HTTPS for public repo reads. |
| `automation/gitops-reconciler.nix:137` | `GIT_SSH_COMMAND` | Already correctly configured with SSH key path. No change needed. |
| `automation/channel-bump.nix:93` | `GIT_SSH_COMMAND` | Same — already correct. |
| `scripts/gitlab-runner-health.sh:276` | HTTPS regex check | The script already handles SSH URLs via `git ls-remote` fallback at line 306. No change needed. |

## Verification Checklist

- [ ] `automation/options.nix:40` example updated to SSH URL
- [ ] `nix fmt -- --check .` passes
- [ ] `nix flake check --no-build` passes
- [ ] `nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name` passes
- [ ] `nix eval .#nixosConfigurations.tuscany.config.system.build.toplevel.name` passes
- [ ] `go build ./...` passes
- [ ] `go test -race -count=1 ./...` passes
- [ ] `ivali flow commit` succeeds
- [ ] `ivali flow push` succeeds
- [ ] `ivali flow mr` succeeds
