# Contributing

This repository is a production NixOS infrastructure. All contributions must follow strict engineering standards.

---

## Getting Started

### Prerequisites

- NixOS or Linux system with Nix
- Go 1.26+
- Git
- Access to GitLab repository

### Development Setup

```bash
# Clone the repository
git clone git@gitlab.com:willisivali/nixos-infrastructure.git
cd nixos-infrastructure

# Install dependencies
go mod download
```

---

## Workflow

### 1. Create an Issue

Every change starts with a GitLab issue. Specify:
- Type (feature/bug/module/security/architecture)
- Domain affected
- Priority (P0/P1/P2/P3)
- Acceptance criteria

### 2. Create a Branch

```bash
git checkout -b feature/your-feature
# or bugfix/your-fix
# or module/new-module
# or security/your-fix
# or architecture/your-change
```

### 3. Make Changes

Follow the [ENGINEERING.md](ENGINEERING.md) rules.

### 4. Verify

```bash
# Go
go build ./...
go test ./...
go vet ./...

# Nix
nix fmt -- --check .

# Shell
bash -n scripts/*.sh
shellcheck scripts/*.sh
```

### 5. Commit

```bash
git add -p  # Stage specific changes
GIT_AUTHOR_NAME="Willis Ivali" GIT_AUTHOR_EMAIL="itsivali@outlook.com" \
GIT_COMMITTER_NAME="Willis Ivali" GIT_COMMITTER_EMAIL="itsivali@outlook.com" \
git commit -m "type(scope): description"
```

**Commit Authorship (MANDATORY):** All commits must be authored as `Willis Ivali <itsivali@outlook.com>`. AI agents must NOT add branding or co-author tags.

Commit format: `type(scope): description`
- Types: feat, fix, module, security, arch, docs, test, chore
- Examples:
  - `feat(deploy): add deployment provenance tracking`
  - `fix(api): add authentication middleware`
  - `module(security): add firewall configuration`

### 6. Push and Create MR

```bash
git push origin feature/your-feature
```

Create a merge request on GitLab referencing the issue.

### 7. Code Review

- All CI checks must pass
- At least 1 approval required from CODEOWNERS
- Address review feedback

### 8. Merge

After approval, merge to main. GitOps will automatically deploy.

---

## Architecture Changes

Architecture changes require additional review:

1. Update architecture manifests (`architecture/*.yaml`)
2. Update ARCHITECTURE.md
3. Update ARCHITECTURE_PROGRESS.md
4. Run architecture linter: `go run ./cmd/check-architecture/`

---

## Security Changes

Security changes require:

1. Security review from @willisivali
2. No plaintext secrets in any form
3. Proper SOPS integration for all secrets
4. Systemd hardening review

---

## Questions?

Open an issue or contact @willisivali on GitLab.
