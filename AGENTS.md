# AGENTS.md

This file provides context for AI agents (OpenCode, Copilot, Claude, etc.) working on this repository.

## Golden Rule: Iterate to Completion, Then Verify Before Push

**Work is only done when every task is complete AND every error it surfaces is solved.**
Never stop at partial success: when one task reveals another problem in the
repository, fix that problem too before declaring the work finished.

### Mandatory Completion Loop

While working on this repository, you MUST:

1. **Iterate through all tasks until all are complete.** Do not stop early or
   hand off unfinished work.
2. **Solve every error you find in the repository**, including pre-existing
   ones unrelated to your current task.
3. **Keep all CI checks passing.** If a change (or an existing state) makes any
   CI job fail, fix it before pushing.
4. **Always run `ivali verify`** before finishing. If it reports any failure,
   fix it and re-run until it exits 0.
5. **Always run `ivali doctor`** before finishing. Read the report and fix
   every failed check (doctor exits non-zero on failures; warnings are
   informational but should be resolved where reasonable).
6. **Always run `nix flake check --no-build`** before finishing (also run
   implicitly by `ivali verify`/`ivali doctor`). Fix any evaluation errors.
7. **Format all `.nix` files with `nix fmt`** before pushing.
8. **Run `go test ./...`** when Go code changed, and fix any failures.
9. **Push to GitLab, never leave work uncommitted or unpushed.** If a
   configuration switch is requested, it must only happen after the change is
   committed, pushed to GitLab, and CI is green.

### Push Gate (in order, before any push)

1. `nix fmt` — format all `.nix` files
2. Commit all changes locally (verify and doctor fail on a dirty tree, so the
   commit must come before the checks)
3. `ivali verify` — must exit 0 (solves: formatting, flake check, duplicates,
   orphans, doc headers, security)
4. `ivali doctor` — must exit 0; fix every failed check
5. `nix flake check --no-build` — must pass (pre-existing warnings like
   Grafana passwords are acceptable)
6. `go test ./...` — must pass when Go code changed
7. `git push origin main` (GitLab only — never push to GitHub directly; the
   mirror does that)
8. Confirm the GitHub Actions run on the mirror goes green before considering
   the work complete

### Switch Gate

`sudo nixos-rebuild switch --flake .#prague` must only be run after the
completion loop and push gate above are satisfied. This prevents broken
configurations from reaching the running system or the GitOps reconciler.

## What This Repository Is

Autonomous NixOS + Home Manager infrastructure for a single-user laptop.
Declarative, reproducible, self-healing, GitOps-driven, Telegram-controlled.

**Primary host:** `prague` (AMD laptop, NixOS 26.11)
**Owner:** Willis Ivali (`ivali`)

## Architecture at a Glance

```
flake.nix
├── hosts/              ← per-host specs (prague.nix, tuscany.nix, testvm.nix)
│   ├── hosts.nix       ← aggregator (auto-discovers hosts/*.nix)
│   ├── default.nix     ← bootstrap template (excluded from registry)
│   └── <name>/         ← hardware-configuration.nix per host
├── configuration.nix   ← top-level module registry (auto-imports everything)
├── lib/host-templates/       ← NixOS host templates (laptop.nix generates full config)
├── security/                 ← SOPS secrets, Tailscale, firewall, hardening
├── boot/                     ← kernel, systemd-boot, sysctl tuning
├── networking/               ← NetworkManager, DNS, timezone
├── desktop/                  ← GNOME lean, GPU acceleration
├── observability/            ← Prometheus, Grafana, Loki, Alloy, Falco
├── recovery/                 ← health checks, rollback, self-heal
├── automation/               ← GitOps reconciler, Telegram bot, CI
├── developer/                ← Go, Node, Python, Terraform toolchains
├── services/                 ← msmtp, bot, nginx, postgres, redis
├── home/                     ← Home Manager (shell, git, editors, fonts, services)
├── packages/                 ← CLI, desktop, system, user package sets
├── lib/                      ← Nix helpers (auto-imports, hardware detection)
├── scripts/                  ← Shell scripts (deploy, health, rollback, bot)
├── internal/                 ← Go CLI (ivali) source code
│   ├── state/                ← Platform state engine (state.Engine)
│   ├── events/               ← Structured event bus (events.Bus)
│   ├── plugin/               ← Plugin architecture + 9 seed plugins
│   ├── inventory/            ← Host inventory discovery
│   ├── docs/                 ← Documentation analysis and quality metrics
│   ├── security/             ← Security scanner with 20+ checks
│   ├── metrics/              ← Prometheus exporter and collector
│   ├── remediation/          ← Auto-remediation engine with 4 actions
│   └── monitor/              ← Health monitor with periodic checks
├── tests/                    ← NixOS smoke tests
└── opencode/                 ← Knowledge base (AI context, architecture, troubleshooting)
```

## How Modules Work

Every top-level directory with a `default.nix` is auto-imported by `configuration.nix`
via `lib/auto-imports.nix`. No manual registration needed.

**To add a new domain module:**
1. Create `newdomain/default.nix`
2. It will be auto-discovered on next rebuild

**To skip a file from auto-import:**
- Prefix with `_` (e.g., `_common.nix`)

**To add a module within an existing domain:**
1. Create `domain/submodule.nix`
2. Import it in `domain/default.nix` (for ordered imports)

## Host Management

Hosts are defined as per-host spec files (`hosts/<name>.nix`), auto-discovered
by `hosts/hosts.nix` (the aggregator). Each host spec is a plain Nix attrset:
- `hostName`, `userName`, `repoPath`
- `tags` (Tailscale ACL), `tailnetDomain`
- `features` (secrets, gitlabRunner, bot, tailscale, ssh)
- `config` (extra NixOS overrides)

The flake generates `nixosConfigurations` dynamically from this registry.
The template `lib/host-templates/laptop.nix` reads `hostSpec` from `specialArgs`
and generates the full NixOS configuration.

**To add a new host:**
1. Create `hosts/<name>.nix` with the host spec (see `hosts/default.nix` for template)
2. Run `ivali bootstrap host <name>` to generate hardware config and secrets
3. Run `nixos-rebuild switch --flake .#<name>`

## Key Commands

### NixOS
```bash
sudo nixos-rebuild switch --flake .#prague    # Apply system config
nix flake check --no-build                     # Validate flake
nix fmt                                        # Format all .nix files
```

### Go CLI
```bash
ivali status          # Repository state summary
ivali doctor          # Full health check
ivali doctor --fix    # Auto-fix issues
ivali docs            # Generate DOCS.md from module headers
ivali docs --analyze  # AI-powered documentation quality analysis
ivali docs --codex    # Generate opencode/modules.md catalog
ivali explain <mod>   # Explain a module
ivali graph tree      # Import hierarchy
ivali graph go-deps   # Go package dependencies
ivali graph tree/deps/ownership --format mermaid  # Mermaid output
ivali graph tree/deps/ownership --format dot      # DOT output
ivali search <query>  # Semantic repository search
ivali inventory       # Comprehensive host inventory
ivali inventory --json# Machine-readable inventory
ivali ai status       # AI system availability (OpenCode + OpenHands)
ivali ai route <desc> # Route task to appropriate AI system
ivali dashboard       # Interactive TUI (8 tabs: Overview, Modules, Health, Domains, Git Log, Generations, Observability, Docs)
ivali bootstrap host  # Generate new host config
ivali monitor         # Real-time system metrics (--json for snapshot)
ivali observability   # Check Prometheus/Grafana/Loki health
ivali metrics         # Repository metrics report (--json, --output)
ivali remediation     # Show auto-remediation history
ivali security-scan   # Comprehensive security scan (--json)
ivali suggest         # Analyze repo and recommend improvements
ivali suggest --auto  # Auto-fix safe issues (duplicate imports)
ivali verify          # Full verification (lint + health + architecture + security)
```

### Scripts
```bash
scripts/deployment-health.sh    # Health check
scripts/rollback.sh             # Rollback to previous generation
scripts/gitops-reconcile.sh     # Pull + rebuild + verify
```

### Telegram Bot

Implemented by the Go bot (`services/bot/ivali-bot-go.nix`,
`ivali-bot-go.service`). The previous shell bot was removed; only the
desktop-bridge helpers (`scripts/bot/lib/desktop.sh`) remain for the smoke test.

```
/status    /health    /deploy    /rollback
/update    /reboot    /shutdown  /cancel
/open      /apps      /run       /git
/screenshot /volume   /brightness /clipboard
/state     /events    /plugins   /inventory
```

## Secrets

All secrets use SOPS with age encryption. Encrypted files in `secrets/`:
- `secrets/tailscale.yaml` — Tailscale auth key, Grafana secret
- `secrets/gitlab-runner.yaml` — GitLab Runner registration token
- `secrets/telegram.yaml` — Bot token, chat ID, email
- `secrets/gitlab.yaml` — GitLab API token
- `secrets/hosts/<name>.yaml` — Per-host secrets

Runtime secrets are at `/run/secrets/` (symlinked by sops-nix).

## CI/CD

**GitLab is the single source of truth; GitHub is a push mirror** (no code
originates on GitHub). Deployment is driven by the GitOps reconciler, not CI:

- **GitLab** — hosts the canonical repo and push-mirrors to GitHub.
- **GitHub Actions** (`.github/workflows/ci.yml`) — validates the mirror
  (Go lint/test/build, shellcheck, `nix fmt`, `nix flake check`, gitleaks) and
  posts the commit status back to GitLab via the GitLab API. No GitLab CI
  minutes are consumed (`.gitlab-ci.yml` was removed).
- **Push workflow** — commit and `git push origin` (GitLab) **only**. A
  GitLab→GitHub push mirror (HTTPS, GitHub PAT) auto-propagates every push to
  GitHub and triggers GitHub Actions. (An SSH deploy key was tried but GitLab
  could not verify `github.com`'s host key, so HTTPS+PAT is used.) Never run
  `git push github` (or the `gpall`/`gph` aliases) directly — that bypasses the
  mirror and is redundant.
- **GitOps reconciler** (`fleet.gitopsReconciler`, enabled on prague) — every
  15 min: `git pull --ff-only → nix flake check → nix build →
  nixos-rebuild switch → health check`. On failure, `deployment-health`
  triggers `scripts/rollback.sh`.

## Conventions

- **Doc headers**: Every `.nix` module should have a standard doc header with
  Purpose, Ownership, Responsibilities, Usage sections
- **Options**: Declare in `options.nix`, implement in sibling files
- **Barrel modules**: Each domain has `default.nix` that imports sub-modules
- **Private files**: Prefix with `_` to skip auto-import
- **SOPS paths**: Use `/run/secrets/<name>` in NixOS modules
- **Home Manager**: User configs in `home/`, wired via flake.nix extraSpecialArgs

## Testing

- `ivali verify` — full verification (formatting, flake check, duplicates,
  orphans, doc headers, security); must exit 0 before finishing
- `ivali doctor` — repository health check; must exit 0 before finishing
- `nix flake check --no-build` — flake validation
- `go test ./...` — Go unit tests
- `nixos-rebuild switch --flake .#prague` — full system rebuild (only after the
  push gate above is satisfied)
- `tests/laptop-smoke.nix` — NixOS VM smoke test

## Common Issues

- **Flake evaluation fails**: Check `hosts/<name>.nix` for syntax errors
- **Module conflict**: Use `lib.mkDefault` or `lib.mkForce` for priority
- **Secret not found**: Verify SOPS config in `.sops.yaml` and encrypted files
- **Home Manager username error**: Ensure `username` is in `extraSpecialArgs`
- **Build timeout**: Large rebuilds may take 10+ minutes on first run
