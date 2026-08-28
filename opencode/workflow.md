# Ivali Flow — Workflow Reference

> **ALL AI agents MUST use ivali flow for every change. No exceptions.**

## The Pipeline

```
UNDERSTAND → CLASSIFY → PLAN → CREATE ISSUE → BRANCH → IMPLEMENT → TEST
    → LOCAL VERIFY → COMMIT → PUSH → MR → CI → MERGE TO MAIN → REPORT
```

## Commands

| Command | Purpose | Gates |
|---------|---------|-------|
| `ivali flow start [type] "desc"` | Create issue + branch | None |
| `ivali flow validate` | Run all verification gates | 7-8 gates |
| `ivali flow commit` | Stage + commit with conventional msg | Blocks main |
| `ivali flow push` | Push branch to GitLab | Clean tree |
| `ivali flow mr` | Create merge request | All commits pushed |
| `ivali flow pipeline` | Check CI status | — |
| `ivali flow pipeline --watch` | Poll CI until terminal | — |
| `ivali flow merge` | Merge when CI passes | CI must pass |
| `ivali flow quick "desc"` | Commit → push → MR (fast) | 3 Go gates only |
| `ivali flow run [type] "desc"` | Full AI pipeline | 4 gates |

## Commit Convention

```
type(scope): description
```

**Types:** `feat`, `fix`, `module`, `security`, `arch`, `docs`, `test`, `chore`

## Branch Convention

```
<type>/<cleaned-description>
```

**Prefixes:** `feature/`, `bugfix/`, `module/`, `security/`, `architecture/`, `docs/`, `maintenance/`

## Commit Authorship (MANDATORY)

```bash
GIT_AUTHOR_NAME="Willis Ivali" GIT_AUTHOR_EMAIL="itsivali@outlook.com" \
GIT_COMMITTER_NAME="Willis Ivali" GIT_COMMITTER_EMAIL="itsivali@outlook.com" \
git commit -m "..."
```

No AI branding in commit messages.

## Verification Sequence (MANDATORY before push)

```bash
# 1. Format check
nix fmt -- --check .

# 2. Shell lint (if scripts modified)
shellcheck --severity=warning scripts/*.sh

# 3. Go checks
go build ./...
go vet ./...
go test -race -count=1 ./...

# 4. Nix checks
nix flake check --no-build
nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name

# 5. Repository checks
ivali verify
ivali doctor
```

## Rules

- **NEVER** commit directly with `git commit`
- **NEVER** push directly with `git push`
- **NEVER** merge directly with `git merge`
- **ALWAYS** use `ivali flow` commands
- **ALWAYS** run verification gates before committing
- **ALWAYS** use Willis Ivali as commit author
- **NEVER** add AI branding to commits

## Definition of Done

A task is DONE only when ALL apply:
- Issue exists, correctly classified
- Branch used correctly
- Implementation complete, tests pass
- All local gates pass
- GitLab CI passes
- MR merged to `main`
- Documentation reflects reality
- Change notification sent
- No production deployment unless explicitly authorized
