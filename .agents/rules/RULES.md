# Workspace Rules — nixos-infrastructure

This workspace enforces the ivali engineering contract for all Antigravity agents.

## Primary Contract

The complete engineering contract is documented in [AGENTS.md](../../AGENTS.md).
All agents MUST read and follow it before making any changes.

Key requirements (summary — read AGENTS.md for the authoritative version):

### Mandatory: Use ivali flow for Every Change

```bash
ivali flow start <type> "description"   # Create issue + branch
ivali flow validate                      # Run all verification gates
ivali flow commit                        # Stage + commit (conventional msg)
ivali flow push                          # Push branch to GitLab
ivali flow mr                            # Create merge request
ivali flow pipeline --watch              # Poll CI until green
ivali flow merge                         # Merge when CI passes
```

NEVER commit directly with `git commit`. NEVER push directly with `git push`.

### Commit Authorship (MANDATORY)

```bash
GIT_AUTHOR_NAME="Willis Ivali" GIT_AUTHOR_EMAIL="itsivali@outlook.com" \
GIT_COMMITTER_NAME="Willis Ivali" GIT_COMMITTER_EMAIL="itsivali@outlook.com" \
git commit -m "..."
```

No AI branding in commit messages.

### Verification Gates (ALL must pass before rebuild)

```bash
nix fmt
nix flake check --no-build
nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.name
```

### Architecture Principles

- One Module = One Capability
- Opt-In by Default (`enable = false`)
- Declarative Only — no imperative package installs
- No plaintext secrets — use SOPS
- Absolute paths via Nix string interpolation

### AI Coding Agent Stack (Fallback Order)

1. `opencode` — primary agent
2. `kilo` — fallback if opencode unavailable
3. `agy` — fallback if kilo unavailable
4. `ai` — wrapper script that cascades through the above

See [IVALI_FLOW.md](../../IVALI_FLOW.md) for the complete workflow reference.
