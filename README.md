# nixos-infrastructure

Autonomous NixOS fleet infrastructure for **prague** — a laptop running a
hardened, monitored, self-healing NixOS system managed entirely through
declarative config, GitOps, and CI/CD.

Built with **Nix flakes**, **Home Manager**, **GitLab CI/CD**, **SOPS secrets**,
**lean GNOME**, **Tailscale**, and a **local observability stack** — all wired
into a control plane that notifies you via Telegram and email.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Fresh Install](#fresh-install)
- [Daily Workflow](#daily-workflow)
- [Control Plane & GitOps](#control-plane--gitops)
- [Telegram Bot Control Plane](#telegram-bot-control-plane)
- [Observability Stack](#observability-stack)
  - [Browser Access](#browser-access-grafana--prometheus)
  - [Telegram Access](#telegram-access-metrics-bot)
  - [Metrics Commands](#metrics-commands)
  - [Health Checks](#health-checks)
  - [Alerting](#alerting)
- [Feature Deep Dives](#feature-deep-dives)
  - [Desktop: Lean GNOME + AMD](#desktop-lean-gnome--amd)
  - [Security: Defence in Depth](#security-defence-in-depth)
  - [Tailscale Mesh](#tailscale-mesh)
  - [Boot & Kernel Tuning](#boot--kernel-tuning)
  - [Developer Toolchain](#developer-toolchain)
  - [Home Manager User Config](#home-manager-user-config)
- [Repository Layout](#repository-layout)
- [Package Management](#package-management)
- [GitLab CI/CD](#gitlab-cicd)
- [Secrets Management](#secrets-management)
- [Multi-Host Deployment](#multi-host-deployment)
- [Roadmap](#roadmap)
- [Safety Notes](#safety-notes)

---

## Features

| Area | What's Included |
|------|----------------|
| **Desktop** | Lean GNOME on Wayland, GDM, AMD GPU acceleration, power management, Bluetooth |
| **Kernel** | `linuxPackages_latest`, custom sysctl hardening, zRAM with zstd compression |
| **Security** | nftables firewall, AppArmor, fail2ban, Tailscale-only SSH, kernel hardening, hardened sudo, security scanning |
| **Networking** | NetworkManager, systemd-resolved (DoT), Tailscale with exit node, BBR congestion control |
| **SSH** | Passwordless, Tailscale-only, ShellFish-compatible, GitLab key auth |
| **Developer** | Node 22, Python 3.13, Go, `tsx`, Flutter/Dart, Nix formatter |
| **Virtualization** | Docker with weekly auto-prune |
| **Observability** | Grafana, Prometheus, Loki, Grafana Alloy, Falco, OTEL collector, journald persistence, SLO tracking, retention policies |
| **CI/CD** | GitLab pipeline with flake checks, binary cache push, SBOM generation, secret detection |
| **GitOps** | Self-healing deployment health monitor, automated reconciler, rollback on failure |
| **Notifications** | Telegram bot + email alerts for build, deploy, health, and rollback events |
| **Secrets** | SOPS-encrypted secrets with age (Tailscale, SMTP, Telegram, Grafana, GitLab Runner) + rotation |
| **Home Manager** | Modular zsh + Powerlevel10k, FZF, zoxide, direnv, Git config (delta), Zed editor, Bitwarden vault, systemd auto-format |
| **Storage** | BTRFS, encrypted swap, aggressive zRAM (100% memory, zstd) |
| **Packages** | Separate CLI and desktop package sets, system-wide vs user-only install surfaces |
| **Telegram Bot** | 41+ commands, role-based access, confirmation dialogs, Prometheus metrics integration |

---

## Architecture

The repository uses a **zero-touch auto-import module system**:

```
flake.nix
  └─ configuration.nix   ← top-level registry
       ├─ hosts/          ← pinned: hardware + host identity
       ├─ desktop/        ← explicit: desktop domain module
       └─ <every other    ← auto-discovered if they have default.nix
           top-level dir>
```

Each domain module uses `lib/auto-imports.nix` to automatically discover all
`.nix` files within its directory — creating a new file is all you need.

The **control plane** ties everything together:

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

---

## Fresh Install

Start from a normal NixOS GNOME installation. Log in as your normal user, not
root, then run:

```bash
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#curl --command bash -c \
  'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
```

The installer will:

- enable `nix-command` and `flakes` in the user Nix config
- fetch Git through a temporary Nix shell
- clone this repository to `~/nixos-infrastructure`
- set `origin` pushes to `git@gitlab.com:willisivali/nixos-infrastructure.git`
- copy `/etc/nixos/hardware-configuration.nix` to `hosts/hardware-configuration.nix`
- install a Git pre-commit hook that formats staged `.nix` files
- run `nix fmt`
- evaluate `.#nixosConfigurations.prague.config.system.build.toplevel.drvPath`
- switch the machine to `.#prague`

After the switch completes, reboot:

```bash
sudo reboot
```

Commit and push the generated hardware file before enabling remote auto-upgrade:

```bash
cd ~/nixos-infrastructure
git add hosts/hardware-configuration.nix
git commit -m "chore: add hardware configuration for prague"
git push
```

The system trusts GitLab.com's SSH host key and sets the `ivali` account to
accept your GitLab public key for inbound SSH. To confirm GitLab SSH access:

```bash
ssh -T git@gitlab.com
```

---

## Daily Workflow

```bash
edit-config    # alias to open ~/nixos-infrastructure in Zed
rebuild        # nixos-rebuild switch --flake .#prague
test-rebuild   # dry build without switching
check          # nix flake check --print-build-logs
fmt            # nix fmt (also runs automatically on save and pre-commit)
update         # nix flake update
clean          # nix store gc
```

Nix files are auto-formatted in two places:

- a Home Manager systemd user service watches `~/nixos-infrastructure`
- a Git pre-commit hook formats staged `.nix` files before commit

---

## Control Plane & GitOps

The system runs a fully automated GitOps control loop that keeps the machine in
sync with the Git repository.

### Deployment Health Monitor

- Runs every **5 minutes** via `deployment-health.timer`
- Checks: systemd health, network connectivity, DNS resolution, GitLab availability,
  GitOps repo integrity, flake evaluation, Tailscale status
- On failure, triggers the GitOps reconciler

### GitOps Reconciler

- Runs every **15 minutes** via `gitops-reconciler.timer`, or immediately on health failure
- Uses a lock file to prevent concurrent runs
- Sequence: `git pull` → `nix flake check` → `nix build` → `nixos-rebuild switch`
- On switch failure: triggers rollback via `scripts/rollback.sh`

### Self-Heal Rollback

- `self-heal.service` runs `nixos-rebuild switch --rollback` when health checks fail
- Re-verifies health after rollback
- Sends success/failure notifications

### GitLab Runner Health

- A separate health monitor checks the GitLab Runner every 10 minutes
- Verifies: service status, runner registration, GitLab connectivity, flake integrity
- Auto-reconciles on failure (re-registers / reconfigures the runner)

### Notifications

All control plane events (build success, build failure, health check failure,
rollback success, rollback failure) trigger alerts through:

- **Telegram** — via bot API (`api.telegram.org`)
- **Email** — via msmtp relay (`smtp.office365.com:587`)

---

## Telegram Bot Control Plane

The system includes a full-featured Telegram bot for remote infrastructure management. The bot runs as a systemd service and provides real-time control over your NixOS system.

### Bot Overview

- **41+ commands** organized by category
- **Role-based access control** (owner/admin/user/guest)
- **Confirmation dialogs** for destructive operations
- **Prometheus metrics integration** for real-time monitoring
- **Inline keyboards** for interactive workflows
- **Typing indicators** and action notifications

### Quick Start

1. **Enable the bot:**
   ```nix
   # In your host configuration
   fleet.bot.enable = true;
   fleet.bot.gitlabUrl = "https://gitlab.com/willisivali/nixos-infrastructure";
   fleet.bot.defaultUser = "ivali";
   ```

2. **Configure secrets:**
   ```bash
   # Add Telegram secrets
   sops secrets/telegram.yaml
   # Add:
   #   telegram_bot_token: <your-bot-token>
   #   telegram_chat_id: <your-chat-id>
   ```

3. **Deploy:**
   ```bash
   sudo nixos-rebuild switch --flake .#prague
   ```

4. **Start chatting:** Send `/start` to your bot in Telegram.

### Command Categories

#### System Monitoring

| Command | Description |
|---------|-------------|
| `/status` | Full system snapshot (CPU, memory, disk, temp, battery, Tailscale) |
| `/status quick` | Quick overview with essential metrics |
| `/status services` | Service health status |
| `/health` | Full deployment health check (11 checks) |
| `/metrics` | System metrics overview |
| `/metrics cpu` | Detailed CPU metrics |
| `/metrics memory` | Memory utilization |
| `/metrics disk` | Disk I/O and usage |
| `/metrics network` | Network traffic |
| `/metrics services` | Service health |
| `/metrics tailscale` | Tailscale status |
| `/metrics prometheus` | Prometheus health |
| `/log [n] [unit]` | Show journal logs (default 50 lines) |
| `/processes` | List running GUI processes |

#### Deployment & Maintenance

| Command | Description |
|---------|-------------|
| `/deploy` | Deploy NixOS configuration (with confirmation) |
| `/update` | Pull + flake update + commit + push |
| `/rollback` | Revert to previous generation (with confirmation) |
| `/gc` | Garbage collect Nix store |
| `/reboot` | Reboot system (with confirmation) |
| `/shutdown` | Power off system (with confirmation) |
| `/cancel` | Abort pending reboot/shutdown |

#### Desktop Control

| Command | Description |
|---------|-------------|
| `/open <app>` | Smart launcher (URLs, folders, apps with fuzzy matching) |
| `/screenshot` | Capture desktop screenshot |
| `/clipboard` | Read clipboard content |
| `/clipboard set <text>` | Set clipboard content |
| `/volume` | Show volume level |
| `/volume <N>` | Set volume to N% |
| `/mute` / `/unmute` | Mute/unmute audio |
| `/brightness` | Show brightness level |
| `/brightness <N>` | Set brightness to N% |
| `/notify <msg>` | Send desktop notification |
| `/windows` | List open windows |
| `/focus <app>` | Focus window by title |
| `/close <app>` | Close window by title |
| `/workspace next/prev/N` | Switch workspaces |
| `/lock` | Lock screen |
| `/logout` | Log out of GNOME |
| `/suspend` | Suspend to RAM |
| `/hibernate` | Hibernate to disk |
| `/monitor-off/on` | Control display power |

#### System Administration

| Command | Description |
|---------|-------------|
| `/run <cmd>` | Execute shell command (admin only) |
| `/git <cmd>` | Run git command in infra repo |
| `/nix <cmd>` | Run arbitrary nix command |
| `/doctor` | Full repository health check |
| `/scan` | Security scan |
| `/security` | Security scan report |
| `/backup` | Show SOPS secrets backup status |
| `/generations` | List NixOS generations |
| `/store` | Nix store status |

#### GitLab Integration

| Command | Description |
|---------|-------------|
| `/gitlab status` | Project + latest pipeline |
| `/gitlab pipelines` | List recent pipelines |
| `/gitlab trigger` | Trigger pipeline (admin only) |
| `/gitlab mr` | List merge requests |

### Role-Based Access Control

The bot supports four user roles with different permission levels:

| Role | Permissions |
|------|-------------|
| **owner** | Full access, can manage users |
| **admin** | Can run destructive commands (deploy, reboot, rollback) |
| **user** | Can run read-only commands (status, health, metrics) |
| **guest** | Can only view status and help |

**Managing users:**
```bash
# Add a user (owner only)
/adduser <chat_id> admin "John Doe"

# Remove a user
/rmuser <chat_id>

# List all users
/users
```

### Confirmation Dialogs

Destructive commands (deploy, rollback, reboot, shutdown) now show inline confirmation buttons:

```
⚠️ Confirm Reboot

Are you sure you want to reboot the system?

Current uptime: 3 days, 5 hours

This action will:
• Stop all running services
• Reboot the system
• Take approximately 1-2 minutes

[✅ Yes, reboot] [❌ Cancel]
```

### Keyboard Shortcuts

The bot provides persistent keyboard buttons for quick access:

```
/status  /health  /metrics
/deploy  /rollback  /help
```

---

## Observability Stack

The observability stack provides comprehensive monitoring, logging, and alerting for your NixOS system.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Collection                          │
├─────────────────────────────────────────────────────────────┤
│  Node Exporter  │  OTel Collector  │  Alloy  │  Falco      │
│  (system metrics)│  (traces/metrics)│  (logs) │  (security) │
└────────┬────────┴────────┬─────────┴────┬────┴──────┬──────┘
         │                 │              │           │
         ▼                 ▼              ▼           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Data Storage                             │
├─────────────────────────────────────────────────────────────┤
│  Prometheus (metrics)  │  Loki (logs)  │  Alertmanager     │
│  15-day retention      │  7-day retention │  (notifications) │
└────────┬───────────────┴───────┬───────┴────────┬──────────┘
         │                       │                │
         ▼                       ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│                    Visualization & Alerting                 │
├─────────────────────────────────────────────────────────────┤
│  Grafana (dashboards)  │  Telegram Bot (metrics)  │ Email  │
│  http://localhost:3000  │  /metrics command         │        │
└─────────────────────────────────────────────────────────────┘
```

### Browser Access (Grafana & Prometheus)

All services are bound to **localhost only** (127.0.0.1) by default for security.

#### Grafana Dashboards

1. **Access Grafana:**
   ```
   http://localhost:3000
   ```

2. **Login credentials:**
   - Username: `admin`
   - Password: Check SOPS secrets or use default `admin`

3. **Pre-configured data sources:**
   - **Prometheus** (default) — metrics queries
   - **Loki** — log queries

4. **Auto-provisioned dashboards:**
   - **NixOS System Overview** — CPU, memory, disk, load, services, generations, network

5. **Creating custom dashboards:**
   - Click **+** → **Create Dashboard**
   - Add panels with PromQL queries

**Useful PromQL queries:**
```promql
# CPU usage percentage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage percentage
(node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# System load
node_load1

# Failed systemd units
node_systemd_unit_state{state="failed"} == 1
```

#### Prometheus

1. **Access Prometheus:**
   ```
   http://localhost:9090
   ```

2. **Features:**
   - Query metrics with PromQL
   - View active targets and scrape status
   - Review alerting rules
   - Examine TSDB storage stats

3. **Available targets:**
   - `node` — system metrics
   - `prometheus` — self-monitoring
   - `tailscale` — Tailscale metrics
   - `otelcol` — OpenTelemetry collector
   - `security-scanner` — security scan results

#### Loki (Logs)

1. **Access Loki:**
   ```
   http://localhost:3100
   ```

2. **Query logs in Grafana:**
   - Select **Loki** data source
   - Use LogQL queries:
     ```
     # All systemd journal entries
     {job="systemd-journal"}

     # Failed services
     {job="systemd-journal"} |= "Failed"

     # Specific unit
     {job="systemd-journal", unit="nginx.service"}
     ```

### Telegram Access (Metrics Bot)

The Telegram bot provides real-time access to all metrics without opening a browser.

#### Quick Metrics

```
/metrics          → System overview (CPU, memory, disk, network, Tailscale)
/metrics cpu      → Detailed CPU info + top processes
/metrics memory   → Memory breakdown + top processes
/metrics disk     → Disk usage + Nix store size
/metrics network  → Network interfaces + traffic
/metrics services → Service health status
/metrics tailscale→ Tailscale connection + peers
/metrics prometheus→ Prometheus health + targets
```

#### System Status

```
/status           → Full system snapshot
/status quick     → Essential metrics only
/status detailed  → Full status + service health
/status services  → Service health only
```

#### Health Checks

```
/health           → 11 deep health checks
/doctor           → Repository health check
/scan             → Security scan
/security         → Security report
```

### Metrics Commands

| Command | Output |
|---------|--------|
| `/metrics` | System overview with CPU, memory, disk, load, uptime, network, Tailscale |
| `/metrics cpu` | CPU usage, cores, frequency, temperature, top processes |
| `/metrics memory` | Memory/swap usage, available memory, top processes |
| `/metrics disk` | Root filesystem, Nix store size, inodes, disk I/O |
| `/metrics network` | Network interfaces, traffic stats, DNS servers, Tailscale |
| `/metrics services` | Critical services status, failed units |
| `/metrics tailscale` | Tailscale IP, host, DNS, key expiry, connected peers |
| `/metrics prometheus` | Prometheus health, targets, rule groups, active series |

### Health Checks

The health endpoint runs 11 deep checks:

| Check | Description |
|-------|-------------|
| `nixos_generation` | Current NixOS generation |
| `systemd_services` | Failed systemd units |
| `disk_space` | Root filesystem usage |
| `memory` | Memory availability |
| `network` | Internet connectivity |
| `tailscale` | Tailscale VPN status |
| `nginx` | Web server status |
| `ssh` | SSH daemon status |
| `prometheus` | Metrics server health |
| `grafana` | Dashboard server health |
| `loki` | Log aggregation health |

**Access health endpoint:**
```bash
curl http://localhost:9100
```

**Response:**
```json
{
  "status": "healthy",
  "host": "prague",
  "checks": {
    "pass": 11,
    "warn": 0,
    "fail": 0
  },
  "details": [
    {"name": "nixos_generation", "status": "pass", "message": "Generation 42"},
    {"name": "systemd_services", "status": "pass", "message": "No failed units"},
    ...
  ],
  "uptime": 259200,
  "generation": 42,
  "timestamp": "2026-07-03T12:00:00Z"
}
```

### Alerting

The system includes Prometheus alerting rules for critical conditions:

#### System Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| `DiskSpaceLow` | <20% disk space | warning |
| `DiskSpaceCritical` | <10% disk space | critical |
| `SystemdServiceFailed` | Any service failed | warning |
| `HighCpuUsage` | >80% for 10 minutes | warning |
| `HighMemoryUsage` | >85% for 5 minutes | warning |

#### Security Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| `SecurityScanFailed` | Security scan failed | critical |
| `SecurityScanStale` | Scan not run in 24h | warning |
| `FailedSystemdUnitsHigh` | >3 failed units | warning |

#### Tailscale Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| `TailscaleServiceDown` | tailscaled not running | critical |
| `TailscaleKeyExpiryWarning` | Key expires in <14 days | warning |
| `TailscaleKeyExpired` | Key has expired | critical |
| `TailscaleMagicDNSFailed` | MagicDNS resolution fails | warning |

#### SLO Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| `SLOErrorBudgetBurnHigh` | Error budget burning at >14.4x | critical |
| `SLOErrorBudgetBurnModerate` | Error budget burning at >6x | warning |
| `SLOErrorBudgetLow` | <25% error budget remaining | warning |
| `SLOErrorBudgetExhausted` | Error budget exhausted | critical |

**Alert routing:** Alerts are routed to Telegram via Alertmanager with HTML formatting.

### Retention Policies

| Data Type | Retention | Storage |
|-----------|-----------|---------|
| **Prometheus metrics** | 15 days | `/var/lib/prometheus` |
| **Loki logs** | 7 days | `/var/lib/loki` |
| **OTel traces** | 3 days | Local filesystem |
| **Systemd journal** | Persistent | `/var/log/journal` |

### Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| **Grafana** | 3000 | Dashboards & visualization |
| **Prometheus** | 9090 | Metrics collection & alerting |
| **Loki** | 3100 | Log aggregation |
| **Health Endpoint** | 9100 | Health check JSON API |
| **NixOS Exporter** | 9101 | NixOS-specific metrics |
| **Tailscale Metrics** | 9121 | Tailscale status metrics |
| **Security Scanner** | 9120 | Security scan metrics |
| **OTel Collector** | 4317/4318 | OTLP gRPC/HTTP |
| **OTel Metrics** | 8888 | OTel self-monitoring |

---

## Feature Deep Dives

### Desktop: Lean GNOME + AMD

A stripped-down GNOME desktop on Wayland with GDM, optimized for laptop use.

**What's included:**
- GNOME core apps (Nautilus, terminal, etc.)
- GDM with auto-suspend after 20 min on login screen
- AMD GPU acceleration (`amdgpu` driver, initrd + X11 + 32-bit)
- `gnome-keyring` with PAM integration (unlocks at login)
- XDG portals (GNOME + GTK fallback)
- Power management: lid suspend, idle suspend after 30 min, upower
- Bluetooth with experimental battery reporting
- Fontconfig: antialias, slight hinting, RGB subpixel

**What's removed (bloat):**
- Online accounts, Tracker indexer, GNOME Software, games
- Epiphany, GNOME Tour, Music, Photos, Weather, Maps, Contacts, Evolution
- PackageKit, geoclue2, printing (disabled by default)

**Desktop applications installed:**
`localsend`, `zoom-us`, `obsidian`, `vlc`, `firefox`, `libreoffice-fresh`

### Security: Defence in Depth

Multiple layers of security stacked together:

| Layer | Technology |
|-------|-----------|
| **Kernel hardening** | `slab_nomerge`, `init_on_alloc=1`, `init_on_free=1`, `pti=on`, `vsyscall=none`, `page_alloc.shuffle=1`, `randomize_kstack_offset=on` |
| **Sysctl hardening** | `kptr_restrict=2`, `dmesg_restrict=1`, `unprivileged_bpf_disabled=1`, `kexec_load_disabled=1`, `perf_event_paranoid=3`, `sysrq=0`, `unprivileged_userns_clone=0` |
| **Firewall** | nftables (not iptables), default deny inbound, Tailscale-only SSH, ping blocked, refuse + packet logging |
| **AppArmor** | Enabled with profiles for bot, CLI, gitops reconciler (complain mode) |
| **Fail2Ban** | SSHD jail + nginx jails + custom telegram-webhook filter |
| **Tailscale** | All SSH access restricted to `tailscale0` interface |
| **SSHD** | Password auth disabled, root login disabled, X11 forwarding off, keyboard-interactive auth off |
| **Sudo** | `execWheelOnly`, 5 min timeout, 3 attempts, PTY required, full logging |
| **Kernel module lockdown** | Module locking enabled, kernel image protected |
| **SOPS secrets** | All credentials encrypted with age — Tailscale, SMTP, Telegram, Grafana, GitLab Runner + rotation |
| **Security scanning** | Daily scans with Prometheus metrics and alerting |

### Tailscale Mesh

Zero-trust networking with Tailscale:

| Feature | Configuration |
|---------|---------------|
| **Exit node** | Enabled by default for internet routing |
| **Split DNS** | Automatic for tailnet domain |
| **SSH** | Tailscale-only via `tailscale0` interface |
| **Key expiry** | Monitored daily, warns 14 days before expiry |
| **MagicDNS** | Hourly health checks |
| **Metrics** | Prometheus integration with connection status |
| **ACL tags** | Build-time validation, automatic tag assignment |

**Adding new hosts:**
1. Add entry to `hosts/hosts.nix`
2. Create `hosts/<name>/hardware-configuration.nix`
3. Deploy with `nixos-rebuild switch --flake .#<name>`

### Boot & Kernel Tuning

- **Kernel:** `linuxPackages_latest` (latest stable)
- **Bootloader:** systemd-boot (10 generation limit)
- **zRAM:** enabled, `zstd` compression, 100% of RAM for compressed swap, priority 100
- **Swappiness:** 180 (aggressive — pushes cold pages to compressed zRAM)
- **Network:** BBR congestion control, `fq` queuing discipline, TCP fast open
- **AMD GPU:** `amdgpu.dc=1`, `amdgpu.audio=0`, `acpi_backlight=native`, IOMMU on
- **Security:** IOMMU enabled, module lockdown, kernel image protection
- **TPM 2.0:** enabled with PKCS#11 support
- **Memory:** tuned watermark, cache pressure, dirty ratios, `max_map_count=1048576`

### Developer Toolchain

Language toolchains installed system-wide via `environment.systemPackages`:

| Language | Tools |
|----------|-------|
| **Nix** | `alejandra`, `nixd` |
| **Go** | `go` |
| **Node.js** | `nodejs_22`, `yarn`, `typescript`, `typescript-language-server`, `tsx` |
| **Python** | `python313`, `ipython`, `pytest`, `uv`, `ruff`, `black`, `mypy` |
| **Flutter/Dart** | Available on request |

### Home Manager User Config

The user environment is split into modular components:

| Module | What It Configures |
|--------|-------------------|
| **Shell** | Zsh, Powerlevel10k, autosuggestions, syntax highlighting, FZF, zoxide, direnv |
| **Git** | Delta (gruvbox diff), git-lfs, gitui, lazygit, aliases, GPG |
| **Editors** | Zed with Nix/Python/Go/TS/React extensions, Gruvbox theme, autosave |
| **Environment** | Session variables, XDG paths, pager settings |
| **Services** | Systemd user service for auto-formatting `.nix` files on change |
| **Bitwarden** | Full vault CLI integration with `bwp` (fzf-based password search) |
| **Fonts** | Nerd Fonts (Meslo, Fira Code, JetBrains Mono), MS Office fonts, Noto |

---

## Repository Layout

```text
.
├── automation/            # GitOps reconciler, health monitors, notifications
├── boot/                  # Kernel, bootloader, zram, sysctl hardening
├── ci/                    # Native NixOS GitLab Runner + pipeline
├── cloud/                 # Cloud provider stubs (AWS, Hetzner, DigitalOcean)
├── desktop/               # GNOME, AMD GPU, power management, apps
├── developer/             # Shell defaults, language toolchains
├── home/                  # Home Manager: shell, git, editors, services, fonts
├── hosts/                 # Host identity + generated hardware config
├── hooks/                 # Git pre-commit hook (auto-format)
├── i18n/                  # Locale and internationalisation
├── lib/                   # Auto-import scanner, utility functions
├── networking/            # NetworkManager, systemd-resolved, Tailscale, time
├── observability/         # Grafana, Prometheus, Loki, Alloy, Falco, OTEL, Alertmanager, SLO
├── opencode/              # AI context, architecture docs, troubleshooting
├── packages/              # CLI, desktop, system, and user package sets
├── recovery/              # Deployment health check, self-heal rollback
├── scripts/               # Install bootstrap, admin, notification, and bot scripts
├── secrets/               # SOPS-encrypted secret files (age)
├── security/              # Firewall, Tailscale, AppArmor, fail2ban, SOPS, scanning
├── services/              # MSMTP email relay + service stubs (nginx, postgres, redis)
├── ssh/                   # SSH daemon hardening + client config
├── storage/               # Filesystem and encryption stubs
├── system/                # Nix daemon, system users, state version
├── tests/                 # NixOS smoke tests
└── virtualization/        # Docker with auto-prune
```

---

## Package Management

CLI tools and desktop applications are separated for clarity:

| File | What Goes There | Installed Via |
|------|----------------|--------------|
| `packages/cli/default.nix` | CLI tools (bat, ripgrep, fzf, git, etc.) | System-wide + Home Manager |
| `packages/desktop/default.nix` | GUI apps (Firefox, Obsidian, VLC, etc.) | System-wide only |

Language toolchains and service-like dependencies go in `developer/` separately.

---

## GitLab CI/CD

The pipeline runs on every push:

| Stage | Job | Description |
|-------|-----|-------------|
| **validate** | `flake-check` | `nix flake metadata` + `nix flake check` |
| **build** | `build-system` | Build NixOS system derivation |
| **cache** | `push-binary-cache` | Push to Cachix (optional) |
| **cache** | `push-attic-cache` | Push to Attic cache (optional) |
| **attest** | `sbom` | Generate SPDX SBOM with syft |
| **secret-detection** | `secret_detection` | GitLab Secret Detection |
| **deploy** | `deploy-fleet` | Manual deploy via tagged self-hosted runner |

Pipeline runs in a `nixos/nix:latest` container with flakes and OIDC auth.

---

## Secrets Management

Secrets are encrypted with **SOPS** using an age key.

| Secrets File | Contents |
|-------------|----------|
| `secrets/tailscale.yaml` | `tailscale_authkey`, `grafana_secret_key` |
| `secrets/telegram.yaml` | `telegram_bot_token`, `telegram_chat_id`, `notify_email` |
| `secrets/smtp.yaml` | `smtp_password`, `smtp_host`, `smtp_user` |
| `secrets/gitlab-runner.yaml` | `gitlab_runner_token` |
| `secrets/hosts/<name>.yaml` | Per-host secrets |

SOPS is configured but disabled at first install so `nixos-rebuild switch` does
not fail before the age key is in place. After installing the key, enable:

```nix
ivali.secrets.enable = true;
```

**Key rotation:**
```bash
# Check key age
sops secrets/tailscale.yaml

# Rotate keys (creates backup + re-encrypts)
scripts/rotate-sops-key.sh
```

---

## Multi-Host Deployment

### Adding a New Host

1. **Add host entry:**
   ```nix
   # hosts/hosts.nix
   newhost = {
     hostName = "newhost";
     userName = "admin";
     tags = [ "tag:admin" "tag:server" ];
     tailnetDomain = "codlet-trench.ts.net";
     features = {
       tailscale = true;
       tailscaleExitNode = false;
       ssh = true;
       secrets = true;
     };
     sopsKeyPath = "/home/admin/.config/sops/age/keys.txt";
   };
   ```

2. **Create hardware config:**
   ```bash
   # On the new host
   sudo nixos-generate-config --show-hardware-config > hosts/newhost/hardware-configuration.nix
   ```

3. **Deploy:**
   ```bash
   sudo nixos-rebuild switch --flake .#newhost
   ```

### Host Features

| Feature | Description |
|---------|-------------|
| `tailscale` | Enable Tailscale VPN |
| `tailscaleExitNode` | Advertise as exit node |
| `ssh` | Enable SSH daemon |
| `secrets` | Enable SOPS secrets |
| `gitlabRunner` | Enable GitLab Runner |
| `bot` | Enable Telegram bot |

### Tailscale Mesh

All hosts connect via Tailscale for secure communication:

```
┌─────────────────────────────────────────┐
│              Tailscale Cloud            │
│         (Coordination + DERP)          │
└─────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
   ┌────┴────┐ ┌────┴────┐ ┌────┴────┐
   │ prague  │ │ server  │ │ laptop  │
   │(primary)│ │(backup) │ │(mobile) │
   └─────────┘ └─────────┘ └─────────┘
```

---

## Roadmap

### Completed

- [x] **Phase 1: Security** — Sysctl hardening, AppArmor, fail2ban, egress firewall, SOPS rotation
- [x] **Phase 2: Tailscale** — ACL tags, key expiry monitoring, MagicDNS health, Prometheus metrics
- [x] **Phase 3: Observability** — Multi-host labeling, Alertmanager, SLOs, Falco split, OTel, retention
- [x] **Phase 4: Telegram Bot** — Inline keyboards, metrics integration, role-based auth, confirmation dialogs

### In Progress

- [ ] **Cloud provisioning** — AWS EC2, Hetzner Cloud, DigitalOcean droplet modules
- [ ] **Web server** — Nginx reverse proxy
- [ ] **Database** — PostgreSQL module
- [ ] **Cache layer** — Redis module

### Planned

- [ ] **Fleet expansion** — Multi-host support (add new hosts by dropping a `hosts/<name>.nix`)
- [ ] **Atuin shell history** — Synced history across hosts
- [ ] **SBOM attestation** — Signed in-toto attestations in CI
- [ ] **Container runtime** — Support for Podman or containerd alongside Docker
- [ ] **Declarative flatpak/flathub** — For GUI apps not in nixpkgs

---

## Safety Notes

- VS Code settings are intentionally mutable. Do not add `programs.vscode.userSettings`.
- Node uses `tsx`; do not add the legacy `ts-node` package.
- Tailscale DNS and routes default to off to avoid broken internet during setup.
- Grafana, Prometheus, Loki, and Alloy are localhost-only unless you explicitly expose them.
- Generated hardware config belongs in `hosts/hardware-configuration.nix`.
- SOPS secrets fail closed — the system works without them, but features that
  require secrets (Tailscale auth, Telegram, SMTP) won't activate until the age
  key is installed.
- The GitOps reconciler uses a lock file — never run `nixos-rebuild switch` manually
  while the reconciler is active.
- The Telegram bot requires proper role-based access control — configure users
  with `/adduser` after initial setup.
- Destructive commands (deploy, reboot, rollback, shutdown) require confirmation
  via inline keyboard buttons.
- Observability services are localhost-only — do not expose ports 3000, 9090, 3100
  to the internet without proper authentication.
