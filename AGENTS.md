# AGENTS.md

This file provides context for AI agents (OpenCode, Copilot, Claude, etc.) working on this repository.

## What This Repository Is

Autonomous NixOS + Home Manager infrastructure for a single-user laptop.
Declarative, reproducible, self-healing, GitOps-driven, Telegram-controlled.

**Primary host:** `prague` (AMD laptop, NixOS 26.11)
**Owner:** Willis Ivali (`ivali`)

## Architecture at a Glance

```
flake.nix
├── hosts/hosts.nix          ← host registry (declarative host specs)
├── configuration.nix         ← top-level module registry (auto-imports everything)
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

Hosts are defined in `hosts/hosts.nix` as a Nix attrset. Each host entry specifies:
- `hostName`, `userName`, `repoPath`
- `tags` (Tailscale ACL), `tailnetDomain`
- `features` (secrets, gitlabRunner, bot, tailscale, ssh)
- `config` (extra NixOS overrides)

The flake generates `nixosConfigurations` dynamically from this registry.
The template `lib/host-templates/laptop.nix` reads `hostSpec` from `specialArgs`
and generates the full NixOS configuration.

**To add a new host:**
1. Add entry to `hosts/hosts.nix`
2. Create `hosts/<name>/hardware-configuration.nix`
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

- `nixos-rebuild switch --flake .#prague` — full system rebuild
- `nix flake check --no-build` — flake validation
- `go test ./...` — Go unit tests
- `tests/laptop-smoke.nix` — NixOS VM smoke test

## Common Issues

- **Flake evaluation fails**: Check `hosts/hosts.nix` for syntax errors
- **Module conflict**: Use `lib.mkDefault` or `lib.mkForce` for priority
- **Secret not found**: Verify SOPS config in `.sops.yaml` and encrypted files
- **Home Manager username error**: Ensure `username` is in `extraSpecialArgs`
- **Build timeout**: Large rebuilds may take 10+ minutes on first run
