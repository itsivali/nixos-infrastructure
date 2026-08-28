# GEMINI.md — Antigravity-Specific Overrides for This Repository

This file contains Antigravity-specific behavior rules.
Universal rules live in AGENTS.md (which Antigravity also reads automatically).

## Ivali Flow (MANDATORY)

After implementing ANY change, you MUST use ivali flow for all Git operations:
1. `ivali flow validate` — run all verification gates
2. `ivali flow commit` — stage and commit (conventional message, Willis Ivali authorship)
3. `ivali flow push` — push branch to GitLab
4. `ivali flow mr` — create merge request
5. `ivali flow pipeline --watch` — wait for CI
6. `ivali flow merge` — merge when CI passes

NEVER commit directly with `git commit`. NEVER push directly with `git push`.
ALWAYS use `ivali flow` commands. This is mandatory.

## Commit Authorship (MANDATORY)

All commits must use:
```bash
GIT_AUTHOR_NAME="Willis Ivali" GIT_AUTHOR_EMAIL="itsivali@outlook.com" \
GIT_COMMITTER_NAME="Willis Ivali" GIT_COMMITTER_EMAIL="itsivali@outlook.com" \
git commit -m "..."
```

No AI branding in commits.

## Verification Before Commit

Always run before committing:
```bash
nix fmt -- --check .
nix flake check --no-build
go build ./...
go test ./...
ivali verify
```

## Commit Convention

Format: `type(scope): description`
Types: feat, fix, module, security, arch, docs, test, chore

## Branch Convention

Format: `<type>/<cleaned-description>`
Prefixes: feature/, bugfix/, module/, security/, architecture/, docs/, maintenance/
