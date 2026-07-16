# nixos-infrastructure

[![GitLab CI](https://img.shields.io/gitlab/pipeline/status/willisivali/nixos-infrastructure?branch=main&label=GitLab+CI)](https://gitlab.com/willisivali/nixos-infrastructure/-/pipelines)
[![GitHub Actions](https://img.shields.io/github/actions/workflow/status/itsivali/nixos-infrastructure/ci.yml?branch=main&label=GitHub+Actions)](https://github.com/itsivali/nixos-infrastructure/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Autonomous NixOS infrastructure for a single laptop — declarative, reproducible,
self-healing, and remotely controllable via Telegram.

Built with **Nix flakes**, **Home Manager**, **GitLab CI/CD** (+ GitHub Actions mirror),
**SOPS secrets**, **lean GNOME**, **Tailscale**, a **Go CLI**, a **Go Telegram bot**,
and a **local observability stack** — all wired into a GitOps control plane.

---

## What This Is

A fully declarative NixOS system for a single user laptop (`prague`). Every aspect
of the machine — kernel, firewall, desktop, services, user environment, secrets,
monitoring — is described in this repository and applied through `nixos-rebuild`.

The system manages itself: a GitOps reconciler pulls changes, builds, and deploys
automatically. If something breaks, it rolls back. If you need to check on it, a
Telegram bot gives you full control from your phone.

---

## Architecture

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
├── developer/                ← Go, Node, Python, Flutter toolchains
├── services/                 ← msmtp, bot, nginx, postgres, redis
├── home/                     ← Home Manager (shell, git, editors, fonts, services)
├── packages/                 ← CLI, desktop, system, user package sets
├── lib/                      ← Nix helpers (auto-imports, hardware detection)
├── scripts/                  ← Shell scripts (deploy, health, rollback, bot)
├── internal/                 ← Go CLI (ivali) source code
├── tests/                    ← NixOS smoke tests
└── opencode/                 ← Knowledge base (AI context, architecture, troubleshooting)
```

### Module System

Every top-level directory with a `default.nix` is auto-imported by `configuration.nix`
via `lib/auto-imports.nix`. No manual registration needed.

**To add a new domain module:**
1. Create `newdomain/default.nix`
2. It will be auto-discovered on next rebuild

**To add a module within an existing domain:**
1. Create `domain/submodule.nix`
2. Import it in `domain/default.nix` (for ordered imports)

**To skip a file from auto-import:**
- Prefix with `_` (e.g., `_common.nix`)

---

## Quick Start

### Fresh Install

```bash
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#curl --command bash -c \
  'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
```

### Daily Commands

| Command | What it does |
|---------|-------------|
| `rebuild` | `nixos-rebuild switch --flake .#prague` |
| `test-rebuild` | Dry build without switching |
| `check` | `nix flake check` |
| `fmt` | Format all `.nix` files |
| `update` | `nix flake update` |
| `clean` | `nix store gc` |

### Go CLI

```bash
ivali status          # Repository state summary
ivali doctor          # Full health check
ivali doctor --fix    # Auto-fix issues
ivali dashboard       # Interactive TUI
ivali bootstrap host  # Generate new host config
ivali graph tree      # Import hierarchy
```

### Go Telegram Bot

```bash
ivali-bot             # Start the Telegram bot
```

---

## Host Management

Hosts are defined in `hosts/hosts.nix` as a Nix attrset. The flake generates
`nixosConfigurations` dynamically from this registry.

```nix
prague = {
  hostName = "prague";
  userName = "ivali";
  repoPath = "/home/ivali/nixos-infrastructure";
  tags = [ "tag:personal" ];
  tailnetDomain = "codlet-trench.ts.net";
  features = {
    secrets = true;
    gitlabRunner = true;
    bot = true;
    tailscale = true;
    tailscaleExitNode = true;
    ssh = true;
  };
  sopsKeyPath = "/home/ivali/.config/sops/age/keys.txt";
};
```

**To add a new host:**
1. Add entry to `hosts/hosts.nix`
2. Create `hosts/<name>/hardware-configuration.nix`
3. Run `nixos-rebuild switch --flake .#<name>`

---

## Security

| Layer | Technology |
|-------|-----------|
| Kernel | `slab_nomerge`, `init_on_alloc/free`, `pti=on`, `vsyscall=none` |
| Firewall | nftables, default deny, Tailscale-only SSH |
| SSH | Password disabled, root disabled, Tailscale interface only |
| Sudo | `execWheelOnly`, 5min timeout, PTY required |
| Secrets | SOPS + age encryption (Tailscale, Telegram, SMTP, Grafana) |
| Monitoring | Daily security scans, AppArmor, fail2ban |

---

## Observability

| Component | Purpose | Port |
|-----------|---------|------|
| **Prometheus** | Metrics collection | 9090 |
| **Grafana** | Dashboards | 3000 |
| **Loki** | Log aggregation | 3100 |
| **Alloy** | Log collection | — |
| **Falco** | Security event detection | — |
| **Health endpoint** | JSON health checks | 9100 |

All services bind to localhost. Access via SSH tunnel or Tailscale.

**Prometheus alerting:** Disk space, high CPU/memory, failed services, Tailscale
key expiry, SLO budget burn — routed to Telegram via Alertmanager.

**Retention:** Prometheus 15d, Loki 7d, systemd journal persistent.

---

## Telegram Bot

A Go-based Telegram bot providing full remote control of the system.

| Category | Commands |
|----------|----------|
| **System** | `/status`, `/health`, `/metrics`, `/log`, `/processes` |
| **Deploy** | `/deploy`, `/update`, `/rollback`, `/reboot`, `/generations` |
| **Desktop** | `/open`, `/screenshot`, `/volume`, `/brightness`, `/windows` |
| **Admin** | `/run`, `/git`, `/nix`, `/doctor`, `/scan`, `/security` |
| **GitLab** | `/gitlab status`, `/gitlab pipelines`, `/gitlab trigger` |

**Access control:** Owner, admin, user, guest roles with confirmation dialogs
for destructive operations (deploy, reboot, rollback, shutdown).

---

## CI/CD

### GitLab (self-hosted runner)

```
validate → test (go, nix) → build → deploy (manual) → notify
```

| Stage | Jobs |
|-------|------|
| test | Go tests, `nix flake check`, NixOS dry-run, security scan |
| build | NixOS toplevel, Home Manager activation, test VM |
| deploy | `ci-deploy.service` (manual trigger) |
| notify | Telegram + email |

### GitHub Actions (mirror)

Portable checks only: `nix flake check`, Go tests, Go build.

---

## Secrets

SOPS-encrypted with age. Files in `secrets/`:

| File | Contents |
|------|----------|
| `tailscale.yaml` | Auth key, Grafana secret |
| `telegram.yaml` | Bot token, chat ID, email |
| `smtp.yaml` | SMTP credentials |
| `gitlab-runner.yaml` | Runner registration token |
| `hosts/<name>.yaml` | Per-host secrets |

Runtime secrets live at `/run/secrets/` (symlinked by sops-nix).

---

## Home Manager

User environment modules in `home/`:

| Module | Configures |
|--------|-----------|
| `shell/` | Zsh, Powerlevel10k, FZF, zoxide, direnv, aliases |
| `git/` | Delta diff, git-lfs, gitui, lazygit |
| `gnome/` | dconf settings, dock favorites |
| `editors/` | Zed editor with extensions |
| `theming.nix` | Fonts, GTK theme |
| `environment/` | Session variables, XDG paths |
| `services/` | Systemd user services |

**Key files:**
- `home/gnome/dconf.nix` — single source of truth for GNOME dconf
- `home/gnome/favorites.nix` — dock favorites (preserves user changes across rebuilds)

---

## Conventions

### Doc Headers

Every `.nix` module has a standard header:

```nix
##############################################################################
#
# Module Name
#
# Purpose
# -------
# What this module does.
#
# Ownership
# ---------
# Options this module declares.
#
##############################################################################
```

### Options Pattern

Options declared in `options.nix`, implementation in sibling files gated with `lib.mkIf`:

```nix
# options.nix
options.ivali.<domain>.enable = lib.mkEnableOption "...";

# service.nix
config = lib.mkIf cfg.enable { services.<name> = { ... }; };
```

### Naming

| Pattern | Meaning |
|---------|---------|
| `default.nix` | Barrel file (imports only) |
| `options.nix` | Option declarations |
| `_*.nix` | Private (skipped by auto-import) |

---

## Repository Layout

```
.
├── automation/        # GitOps, health monitors, notifications
├── boot/              # Kernel, bootloader, zram, sysctl
├── cmd/               # Go CLI entry points (ivali, bw-tui, ivali-bot)
├── desktop/           # GNOME, GPU, power management
├── developer/         # Language toolchains
├── home/              # Home Manager config
├── hosts/             # Host registry + hardware configs
├── internal/          # Go source (ivali, telegram bot, config, logger)
├── lib/               # Auto-imports, host templates, helpers
├── networking/        # NetworkManager, DNS, Tailscale
├── observability/     # Grafana, Prometheus, Loki, Alloy, Falco
├── packages/          # CLI, desktop, system, user package sets
├── recovery/          # Health checks, rollback, self-heal
├── scripts/           # Shell scripts (deploy, bot, admin)
├── secrets/           # SOPS-encrypted secret files
├── security/          # Firewall, Tailscale, AppArmor, fail2ban
├── services/          # msmtp, bot, nginx, postgres, redis
├── ssh/               # SSH daemon + client config
├── tests/             # NixOS smoke tests
└── virtualization/    # Docker
```

---

## Safety Notes

- `nixos-rebuild boot` (not `switch`) is preferred when the display might drop
- Observability stack is currently disabled on `prague` (laptop hardware limit)
- Tailscale DNS/routes default to off during setup
- Grafana, Prometheus, Loki are localhost-only unless explicitly exposed
- GitOps reconciler uses a lock file — avoid manual `nixos-rebuild` during reconciliation
- SOPS secrets fail closed — features requiring secrets won't activate until the age key is installed
