# Engineering Rules

This document defines the engineering contract for every AI agent and human developer working on this repository.

---

## Core Philosophy

- **Production-Grade:** Every implementation is production software
- **Holistic:** Every feature must feel complete and integrated
- **End-to-End:** Every workflow must function from start to finish
- **Zero Tolerance:** No unfinished features, dead code, or placeholder implementations

---

## Coding Standards

### Nix/NixOS

- **One Module = One Capability:** Do not mix unrelated services
- **Opt-In by Default:** All modules must be disabled by default
- **Use `lib.mkIf`:** For conditional configuration
- **Use `lib.mkOption`:** For all configurable values
- **Absolute Paths:** Always use Nix string interpolation, never relative paths
- **Self-Documenting:** Use `description` fields for all options

### Go

- **Interfaces:** Define interfaces for testability
- **Error Handling:** Always check errors, wrap with `fmt.Errorf("context: %w", err)`
- **Testing:** Every function must have at least one test case
- **No Panics:** Return errors instead of panicking
- **Package Structure:** One capability per package

### Shell Scripts

- **`set -euo pipefail`:** Always at the top
- **Quote Variables:** Always use `"$variable"` not `$variable`
- **No `eval`:** Never use `eval` unless absolutely necessary
- **Absolute Paths:** Use Nix string interpolation for tool paths

---

## Security Rules

### Secrets Management

- **No Plaintext:** Never commit passwords, API keys, or tokens
- **SOPS Only:** All secrets must be managed via SOPS/agenix
- **No Hardcoded Secrets:** Never hardcode secret values, not even as defaults

### Service Hardening

- **Least Privilege:** Services must use minimal permissions
- **DynamicUser:** Use when possible
- **ProtectSystem:** Use `ProtectSystem = "strict"` when possible
- **NoNewPrivileges:** Always enable for systemd services

---

## Testing Requirements

### Unit Tests

- Every function must have at least one test
- Every conditional branch must be exercised
- Tests must be deterministic

### Integration Tests

- End-to-end feature testing required
- Desktop changes: verify launching, keybindings, theming
- Service changes: verify systemd units, logs, health checks

### Pre-Commit Verification

1. `go build ./...`
2. `go test ./...`
3. `go vet ./...`
4. `nix fmt -- --check .`
5. `bash -n scripts/*.sh`

---

## Architecture Rules

### Deployment

- **Git is Source of Truth:** All configuration lives in Git
- **GitLab CI Validates Only:** CI never deploys
- **GitOps Reconciles:** Only GitOps deploys to production
- **Single Deployment Engine:** All paths route through `internal/operations/`

### Branching

- **main is Production:** Only production branch
- **Feature Branches:** `feature/*`, `bugfix/*`, `module/*`, `security/*`
- **No Direct Pushes:** All changes flow through merge requests
- **CI Must Pass:** Before merge is allowed

### Module Boundaries

- **No Cross-Domain State:** One domain must not directly modify another's state
- **Explicit Interfaces:** Domains communicate through documented APIs
- **State Ownership:** Every state directory has exactly one owner

---

## Documentation

### Required for New Modules

- README.md explaining purpose, options, troubleshooting
- Self-documenting code with `description` fields
- Comments only when necessary (not for obvious code)

### Required for Significant Changes

- Update ARCHITECTURE.md if domain boundaries change
- Update relevant documentation files
- Add entries to architecture manifests if applicable

---

## CI/CD Rules

### GitLab CI

- Lint → Architecture → Test → Check → Build
- No deploy stage (deployment through GitOps only)
- All gates must pass before merge

### GitHub Actions

- Mirror only (go-lint, go-test, ci-summary)
- Not the source of truth

---

## Enforcement

These rules are enforced by:

1. **GitLab CI:** Automated validation on every push
2. **Architecture Linter:** Validates domain boundaries
3. **CODEOWNERS:** Requires review from @willisivali
4. **Merge Requests:** All changes require review

Violations of these rules will be caught by CI and blocked from merging.
