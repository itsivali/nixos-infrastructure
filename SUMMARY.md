# NixOS Infrastructure — Complete System Summary

**Repository:** `willisivali/nixos-infrastructure`
**Owner:** Willis Ivali (`ivali`)
**Primary Host:** `prague` (AMD laptop, NixOS 26.11)
**Last Updated:** July 2026

---

## Executive Summary

This repository implements a **fully autonomous, self-healing NixOS infrastructure** for a single-user laptop. It combines declarative system configuration, GitOps automation, a custom Go CLI (`ivali`), a Telegram bot control plane, and a complete observability stack — all designed to be reproducible, auditable, and zero-touch after initial setup.

The system can bootstrap itself on a fresh NixOS installation, detect hardware, configure services, and maintain itself indefinitely through automated reconciliation, health monitoring, and rollback mechanisms.

---

## Core Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        User Interface Layer                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Telegram Bot │  │  SSH Access  │  │  GNOME Desktop        │  │
│  │  (37 commands)│  │  (Tailscale) │  │  (Wayland, GDM)       │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│                      Control Plane Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  ivali CLI   │  │  GitOps      │  │  Health Monitor          │  │
│  │  (21 commands)│  │  Reconciler  │  │  (every 5 min)           │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│                    NixOS System Layer                                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Flake: nixosConfigurations.prague                           │  │
│  │  ├── configuration.nix (auto-imports all domain modules)     │  │
│  │  ├── lib/host-templates/laptop.nix (host template)          │  │
│  │  └── home/ivali.nix (Home Manager user config)              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │  Boot    │  │  Desktop │  │  Security│  │  Observability   │  │
│  │  Kernel  │  │ GNOME    │  │  Harden  │  │  Prometheus      │  │
│  │  zRAM    │  │  AMD GPU │  │  SOPS    │  │  Grafana         │  │
│  │  systemd │  │  Power   │  │  Tailscale│ │  Loki            │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Feature Inventory

### 1. Multi-Host Flake Architecture

| Component | Location | Description |
|-----------|----------|-------------|
| `flake.nix` | Root | Multi-host flake generating `nixosConfigurations` from host registry |
| `hosts/hosts.nix` | Host Registry | Auto-aggregator discovering per-host specs from `hosts/*.nix` |
| `lib/host-templates/laptop.nix` | Template | NixOS module reading `hostSpec` from `specialArgs` |
| `hosts/<name>/hardware-configuration.nix` | Hardware | Auto-generated hardware config per host |

**Adding a new host:**
1. Create `hosts/<name>.nix` with the host spec
2. Run `ivali bootstrap host <name>`
3. Commit and push

**Supported hosts:**
- `prague` — Primary laptop (AMD, full features)
- `testvm` — Test host (minimal features)

### 2. Go CLI (`ivali`)

**Location:** `internal/commands/` (21 commands)

| Command | Description |
|---------|-------------|
| `ivali status` | Repository state summary |
| `ivali doctor` | Full health check with recommendations |
| `ivali doctor --fix` | Auto-fix issues |
| `ivali explain <module>` | Explain any NixOS module |
| `ivali docs --codex` | Generate DOCS.md + opencode/modules.md |
| `ivali graph tree` | Import hierarchy visualization |
| `ivali metrics` | Repository intelligence (JSON output) |
| `ivali scan` | Security scan |
| `ivali health` | System health check |
| `ivali dashboard` | Interactive TUI dashboard |
| `ivali bootstrap host` | Generate new host configuration |
| `ivali rebuild` | NixOS rebuild wrapper |
| `ivali update` | Update flake inputs |
| `ivali verify` | Verify configuration |
| `ivali suggest` | Suggest improvements |
| `ivali deploy` | Deployment wrapper |
| `ivali reconcile` | GitOps reconciliation |
| `ivali extract` | Extract documentation |
| `ivali update` | Update flake inputs |

### 3. Telegram Bot (Go)

**Location:** `services/bot/ivali-bot-go.nix` (`cmd/ivali-bot`)

| Category | Commands |
|----------|----------|
| **System** | `/status`, `/health`, `/reboot`, `/shutdown`, `/cancel` |
| **Deployment** | `/deploy`, `/rollback`, `/update`, `/git` |
| **Observability** | `/metrics`, `/scan`, `/security`, `/doctor` |
| **Desktop** | `/open`, `/apps`, `/run`, `/screenshot`, `/clipboard` |
| **Media** | `/volume`, `/brightness`, `/desktop_power` |
| **Store** | `/store`, `/generations`, `/backup`, `/gc` |
| **Development** | `/git_cmd`, `/gitlab_cmd`, `/nix_cmd`, `/log`, `/processes` |
| **Navigation** | `/menu`, `/help`, `/windows`, `/workspace`, `/firefox` |

### 4. Observability Stack

**Location:** `observability/`

| Service | Port | Purpose | Status |
|---------|------|---------|--------|
| **Prometheus** | 9090 | Metrics collection | ✅ Enabled |
| **Grafana** | 3000 | Dashboard server | ✅ Enabled |
| **Loki** | 3100 | Log aggregation | ✅ Enabled |
| **Grafana Alloy** | — | Journal → Loki forwarder | ✅ Enabled |
| **Falco** | — | Runtime security detection | ✅ Enabled |
| **OTEL Collector** | — | OpenTelemetry pipeline | ✅ Enabled |
| **Node Exporter** | 9100 | System metrics | ✅ Enabled |
| **NixOS Exporter** | 9101 | NixOS-specific metrics | ✅ Enabled |
| **Health Endpoint** | 9102 | HTTP health check | ✅ Enabled |

**Data flow:**
```
systemd journal ─→ Grafana Alloy ─→ Loki ─→ Grafana
                                        ↗
Prometheus ─→ node exporter ──────────┘
             ─→ nixos exporter ────────┘
             ─→ self ──────────────────┘
```

**Alerting Rules:**
- Disk space warnings (< 20%, < 10%)
- Service failures
- High CPU usage (> 80%)
- High memory usage (> 85%)
- NixOS generation drift

**Grafana Dashboards:**
- NixOS System Overview (CPU, memory, disk, services, network)

### 5. Security Hardening

**Location:** `security/`

| Layer | Technology | Status |
|-------|-----------|--------|
| **Kernel** | `slab_nomerge`, `init_on_alloc=1`, `init_on_free=1`, `pti=on` | ✅ Enabled |
| **Sysctl** | `kptr_restrict=2`, `dmesg_restrict=1`, `perf_event_paranoid=3` | ✅ Enabled |
| **Firewall** | nftables, default deny, Tailscale-only SSH | ✅ Enabled |
| **AppArmor** | Mandatory access control | ✅ Enabled |
| **Fail2Ban** | SSHD jail, 3 retries, 1h ban | ✅ Enabled |
| **SSH** | Password auth disabled, root login disabled | ✅ Enabled |
| **Sudo** | `execWheelOnly`, 5 min timeout, PTY required | ✅ Enabled |
| **Secrets** | SOPS with age encryption | ✅ Enabled |
| **Scanning** | Daily security scan service | ✅ Enabled |

**SOPS Secrets:**
- `secrets/tailscale.yaml` — Tailscale auth key, Grafana secret
- `secrets/notifications.yaml` — Email notifications
- `secrets/gitlab-runner.yaml` — Runner registration token
- `secrets/gitlab.yaml` — GitLab API token
- `secrets/hosts/<name>.yaml` — Per-host secrets

### 6. Boot & Kernel

**Location:** `boot/`

| Feature | Configuration |
|---------|---------------|
| **Kernel** | `linuxPackages_6_18` (6.18 LTS — pinned for RTL8821CE wifi) |
| **Bootloader** | systemd-boot (10 generation limit) |
| **zRAM** | Enabled, zstd compression, 100% RAM |
| **Swappiness** | 180 (aggressive) |
| **Network** | BBR congestion control, `fq` queuing |
| **AMD GPU** | `amdgpu.dc=1`, `amdgpu.audio=0` |
| **Security** | IOMMU, module lockdown, kernel image protection |
| **TPM** | 2.0 enabled with PKCS#11 |

### 7. Networking

**Location:** `networking/`

| Feature | Configuration |
|---------|---------------|
| **Manager** | NetworkManager |
| **DNS** | systemd-resolved (Cloudflare + Quad9, DoT) |
| **DNSSEC** | allow-downgrade |
| **Tailscale** | VPN with exit node, DNS off, routes off |
| **Timezone** | Africa/Nairobi |

### 8. Desktop

**Location:** `desktop/`

| Feature | Configuration |
|---------|---------------|
| **Environment** | GNOME (Wayland) |
| **Display** | GDM (login manager) |
| **GPU** | AMD acceleration (amdgpu) |
| **Power** | Lid suspend, idle suspend, UPower |
| **Bluetooth** | Enabled with battery reporting |
| **Fonts** | Nerd Fonts, MS Office fonts, Noto |
| **Apps** | Nautilus (files), Loupe (images), Papers (PDF), File Roller (archives), GNOME Text Editor/Calculator, GNOME Terminal, Firefox (with Sidebery), dash-to-panel taskbar |

### 9. Developer Toolchain

**Location:** `developer/`

| Language | Tools |
|----------|-------|
| **Nix** | `alejandra`, `nixd` |
| **Go** | `go` |
| **Node.js** | `nodejs_22`, `yarn`, `typescript`, `tsx` |
| **Python** | `python313`, `ipython`, `pytest`, `uv`, `ruff`, `black`, `mypy` |

### 10. Home Manager

**Location:** `home/`

| Module | What It Configures |
|--------|-------------------|
| **Shell** | Zsh, Powerlevel10k, FZF, zoxide, direnv |
| **Git** | Delta, git-lfs, gitui, lazygit |
| **Editors** | Zed with Nix/Python/Go/TS/React extensions |
| **Environment** | Session variables, XDG paths |
| **Services** | Auto-format `.nix` files on change |
| **Bitwarden** | CLI integration with fzf search |
| **Fonts** | Nerd Fonts (Meslo, Fira Code, JetBrains Mono) |

### 11. Services

**Location:** `services/`

| Service | Purpose | Status |
|---------|---------|--------|
| **Nginx** | Reverse proxy for Grafana/Prometheus | ✅ Implemented |
| **PostgreSQL** | Database for Grafana/local apps | ✅ Implemented |
| **Valkey** | Open-source Redis fork (cache) | ✅ Implemented |
| **MSMTP** | Email relay for notifications | ✅ Implemented |

### 12. GitOps & Recovery

**Location:** `automation/`, `recovery/`

| Component | Description | Status |
|-----------|-------------|--------|
| **Deployment Health** | Runs every 5 min, checks system health | ✅ Enabled |
| **GitOps Reconciler** | Runs every 15 min, syncs with Git | ✅ Enabled |
| **Self-Heal Rollback** | Automatic rollback on failure | ✅ Enabled |
| **Notifications** | Telegram + email alerts | ✅ Enabled |

**Self-healing flow:**
```
deployment-health.timer (every 5 min)
  └─ deployment-health.service
       └─ scripts/deployment-health.sh
            └─ on failure → gitops-reconciler.service
                              └─ scripts/gitops-reconcile.sh
                                   ├─ git pull + nix flake check
                                   ├─ nix build + nixos-rebuild switch
                                   ├─ post-deployment health check
                                   ├─ on failure → scripts/rollback.sh
                                   └─ Telegram + email notifications
```

### 13. CI/CD Pipeline

**Location:** `.github/workflows/ci.yml`

GitLab is the single source of truth and push-mirrors to GitHub. GitHub
Actions validates the mirror and posts the commit status back to GitLab;
deployment is driven by the GitOps reconciler, not CI.

| Stage | Job | Description |
|-------|-----|-------------|
| **test** | `go-lint`, `go-test`, `go-build` | Go lint/test/build |
| **test** | `shell-lint` | ShellCheck scripts |
| **build** | `nix-format`, `nix-flake-check` | `nix fmt --check`, `nix flake check` |
| **security** | `secret-scan` | gitleaks |
| **validate** | `nixos-build` | Build NixOS toplevel + Home Manager (self-hosted) |
| **status** | `gitlab-status` | Posts commit status to GitLab |

### 14. Testing

**Location:** `tests/`

| Test | Description |
|------|-------------|
| `laptop-smoke.nix` | Basic NixOS system services |
| `security-smoke.nix` | Security hardening verification |
| `observability-smoke.nix` | Observability stack verification |
| `home-manager-smoke.nix` | Home Manager configuration |
| `services-smoke.nix` | Nginx, PostgreSQL, Valkey services |
| `automation-smoke.nix` | GitOps reconciler, health checks |

---

## Repository Layout

```
nixos-infrastructure/
├── flake.nix                    # Multi-host flake entry point
├── configuration.nix            # Top-level module registry (auto-imports)
├── hosts/                       # Host registry and hardware configs
│   ├── hosts.nix                # Central host definitions
│   └── hardware-configuration.nix
├── lib/                         # Nix libraries
│   ├── auto-imports.nix         # Auto-discovery system
│   ├── host-templates/          # NixOS host templates
│   │   ├── laptop.nix           # Full laptop configuration
│   │   └── default.nix
│   └── hardware-detection.nix   # Hardware detection utilities
├── internal/                    # Go CLI source
│   └── commands/                # 21 CLI commands
├── scripts/                     # Shell scripts
│   ├── bot/commands/            # 37 Telegram bot commands
│   ├── deployment-health.sh     # Health check script
│   ├── gitops-reconcile.sh      # GitOps reconciliation
│   └── rollback.sh              # Rollback script
├── automation/                  # GitOps and notifications
├── boot/                        # Kernel, bootloader, zRAM
├── networking/                  # NetworkManager, DNS, Tailscale
├── desktop/                     # GNOME, GDM, AMD GPU, power
├── security/                    # Hardening, firewall, SOPS
├── observability/               # Prometheus, Grafana, Loki
├── services/                    # Nginx, PostgreSQL, Valkey
├── developer/                   # Language toolchains
├── home/                        # Home Manager user config
├── packages/                    # CLI, desktop, system packages
├── recovery/                    # Health checks, rollback
├── ssh/                         # SSH daemon and client
├── storage/                     # BTRFS, encryption stubs
├── virtualization/              # Docker
├── tests/                       # NixOS VM smoke tests
├── opencode/                    # AI knowledge base
├── secrets/                     # SOPS-encrypted secrets
├── AGENTS.md                    # AI context file
├── DOCS.md                      # Generated documentation
└── ivali                        # Compiled Go binary
```

---

## Key Commands

### NixOS Management
```bash
sudo nixos-rebuild switch --flake .#prague    # Apply system config
nix flake check --no-build                     # Validate flake
nix fmt                                        # Format all .nix files
nix flake update                               # Update inputs
```

### Go CLI
```bash
ivali status          # Repository state summary
ivali doctor          # Full health check
ivali doctor --fix    # Auto-fix issues
ivali explain <mod>   # Explain any module
ivali docs --codex    # Generate documentation
ivali graph tree      # Import hierarchy
ivali metrics         # Repository intelligence (JSON)
ivali scan            # Security scan
ivali health          # System health
ivali dashboard       # Interactive TUI
ivali bootstrap host  # Generate new host config
ivali rebuild         # NixOS rebuild wrapper
ivali update          # Update flake inputs
ivali verify          # Verify configuration
ivali suggest         # Suggest improvements
ivali deploy          # Deployment wrapper
ivali reconcile       # GitOps reconciliation
ivali extract         # Extract documentation
```

### Scripts
```bash
scripts/deployment-health.sh    # Health check
scripts/rollback.sh             # Rollback to previous generation
scripts/gitops-reconcile.sh     # Pull + rebuild + verify
scripts/install-fresh-nixos.sh  # Universal bootstrap
```

### Telegram Bot
```
/status    /health    /deploy    /rollback
/update    /reboot    /shutdown  /cancel
/open      /apps      /run       /git
/screenshot /volume   /brightness /clipboard
/metrics   /scan      /security  /doctor
/store     /generations /backup  /gc
```

---

## Fresh Install

From a normal NixOS installation:

```bash
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#curl --command bash -c \
  'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
```

The installer will:
1. Enable flakes in user Nix config
2. Clone the repository to `~/nixos-infrastructure`
3. Copy hardware configuration
4. Install Git pre-commit hook
5. Run `nix fmt`
6. Evaluate and switch to `.#prague`
7. Reboot

---

## Configuration Options

### Host-Level Options (from `hosts/hosts.nix`)

```nix
{
  hostName = "prague";
  userName = "ivali";
  repoPath = "/home/ivali/nixos-infrastructure";
  tags = [ "tag:admin" ];
  tailnetDomain = "codlet-trench.ts.net";
  features = {
    secrets = true;
    gitlabRunner = true;
    bot = true;
    tailscale = true;
    tailscaleExitNode = true;
    ssh = true;
  };
}
```

### Module-Level Options

```nix
# Observability
ivali.observability.enable = true;
ivali.observability.healthEndpoint.enable = true;
ivali.observability.exporters.enable = true;

# Security
ivali.security.scanning.enable = true;
ivali.secrets.enable = true;

# Services
ivali.services.nginx.enable = true;
ivali.services.postgres.enable = true;
ivali.services.valkey.enable = true;

# SSH
ivali.ssh.enable = true;
ivali.ssh.tailscaleOnly = true;

# Tailscale
ivali.tailscale.enable = true;
ivali.tailscale.advertiseExitNode = true;
```

---

## Verification Status

| Check | Status |
|-------|--------|
| `nix flake check --no-build` | ✅ Passes |
| `go build ./cmd/ivali/` | ✅ Compiles |
| `go test ./internal/...` | ✅ All 11 tests pass |
| `ivali bootstrap host` | ✅ Generates valid config |
| `ivali docs --codex` | ✅ Generates documentation |
| `nix eval .#nixosConfigurations.prague.config...` | ✅ All services enabled |

---

## Git History (Recent)

```
4af626e feat: add comprehensive VM tests for services and automation
6d44bf7 feat: add /scan bot command for security scanning
617f072 feat: add nixos-rebuild dry-run and security scan to CI/CD
27146fe feat: add Prometheus alerting rules and Grafana dashboards
6a868a9 feat: replace Redis with Valkey (open-source Redis fork)
d675c20 feat: fill in service stubs (nginx, postgres, redis)
9abb630 fix: update test files to use new NixOS test API
5d2cc71 feat: enable security scanning in host template
11cbed6 feat: enable observability services in host template
0866088 fix: bootstrap host command and template generator
```

---

## What Makes This System Unique

1. **Self-Healing:** Automatic rollback when health checks fail
2. **Declarative:** Everything defined in Nix, reproducible across reinstalls
3. **Multi-Host:** Single repository manages multiple machines
4. **AI-Ready:** AGENTS.md + opencode/ knowledge base for AI assistance
5. **Zero-Touch:** GitOps reconciliation keeps system in sync with Git
6. **Observable:** Full metrics, logs, and dashboards out of the box
7. **Secure:** Defense in depth with 10+ security layers
8. **Controllable:** Telegram bot (Go) for remote management
9. **Auditable:** Every change tracked in Git with full history
10. **Portable:** Bootstrap script works on any fresh NixOS installation

---

## Future Roadmap

### Completed
- ✅ Multi-host flake architecture
- ✅ Go CLI with 21 commands
- ✅ Telegram bot (Go) for remote management
- ✅ Full observability stack
- ✅ Security hardening
- ✅ Self-healing recovery
- ✅ CI/CD pipeline
- ✅ Service stubs (nginx, postgres, valkey)
- ✅ Prometheus alerting rules
- ✅ Grafana dashboards
- ✅ VM smoke tests
- ✅ `ivali bootstrap host` command
- ✅ `ivali metrics` command
- ✅ Security scanning service

### In Progress
- 🔄 Cloud provisioning (AWS, Hetzner, DigitalOcean)
- 🔄 BTRFS tuning and snapshot management
- 🔄 Disk encryption (LUKS)

### Planned
- 📋 Fleet expansion (multi-host)
- 📋 Atuin shell history sync
- 📋 SBOM attestation in CI
- 📋 Podman/containerd support
- 📋 Declarative flatpak/flathub
- 📋 Alert manager integration
- 📋 More comprehensive VM tests

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| **NixOS Modules** | 67+ |
| **Home Manager Modules** | 42+ |
| **Go Commands** | 21 |
| **Telegram Commands** | 37 |
| **VM Tests** | 6 |
| **Documentation Files** | 5 (opencode/) |
| **SOPS Secret Files** | 4 + per-host |
| **CI/CD Pipeline Stages** | 4 (test, build, deploy, notify) |
| **Security Layers** | 10+ |
| **Observability Services** | 9 |
| **System Services** | 4 (nginx, postgres, valkey, msmtp) |
| **Health Check Frequency** | Every 5 minutes |
| **GitOps Reconcile Frequency** | Every 15 minutes |

---

*Generated by `ivali docs --codex` — 112 documented modules*
