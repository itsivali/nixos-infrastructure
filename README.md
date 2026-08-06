# nixos-infrastructure

[![GitHub Actions](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Autonomous NixOS infrastructure for a single-user laptop — declarative, reproducible,
self-healing, and remotely controllable via Telegram.

**Primary host:** `prague` (AMD laptop, NixOS 26.11)
**Owner:** Willis Ivali (`ivali`)

---

## What This Is

A fully declarative NixOS system. Every aspect of the machine — kernel, firewall,
desktop, services, user environment, secrets, monitoring — is described in this
repository and applied through `nixos-rebuild`. The system manages itself through a
GitOps control plane: it pulls changes, builds, deploys, and rolls back on failure.
A Telegram bot gives you full remote control from your phone.

The codebase spans **187 Nix modules**, **70 Go files**, and **79 shell scripts** —
all wired together through a zero-touch auto-import module system.

---

## Features

| Area | What's Included |
|------|----------------|
| **Desktop** | Hyprland on Wayland, GTK/GNOME applications, Ly login, AMD GPU acceleration, power management, Bluetooth |
| **Kernel** | `linuxPackages_6_18` (6.18 LTS — pinned for RTL8821CE wifi), custom sysctl hardening, zRAM with zstd compression |
| **Security** | nftables firewall, AppArmor, fail2ban, Tailscale-only SSH, kernel hardening |
| **Networking** | NetworkManager, systemd-resolved (DoT), Tailscale with exit node, BBR |
| **SSH** | Passwordless, Tailscale-only, ShellFish-compatible |
| **Developer** | Go, Node 22, Python 3.13, Flutter/Dart, Nix formatter |
| **Observability** | Grafana, Prometheus, Loki, Alloy, Falco, OTEL, SLO tracking, alerting |
| **GitOps** | Self-healing health monitor, automated reconciler, rollback on failure |
| **Telegram Bot** | 30+ commands, role-based access, desktop control, system admin, GitLab integration |
| **Go CLI** | `ivali` — repository management, health checks, dashboard, bootstrapping |
| **Secrets** | SOPS-encrypted with age (Tailscale, Telegram, SMTP, Grafana, GitLab) |
| **Home Manager** | Zsh + Powerlevel10k, FZF, zoxide, direnv, Zed editor, Bitwarden, Nerd Fonts |
| **CI/CD** | GitLab source of truth + GitHub Actions mirror (validates, posts status to GitLab); deploy via GitOps reconciler |
| **Storage** | BTRFS, encrypted swap, aggressive zRAM |
| **Packages** | Separate CLI and desktop package sets |

---

## Architecture

### System Architecture

```
flake.nix
├── hosts/              ← per-host specs (prague.nix, tuscany.nix, testvm.nix)
│   ├── hosts.nix       ← aggregator (auto-discovers hosts/*.nix)
│   ├── default.nix     ← bootstrap template (excluded from registry)
│   └── <name>/         ← hardware-configuration.nix per host
├── configuration.nix   ← top-level module registry (auto-imports everything)
├── lib/host-templates/           ← NixOS host templates (generates full config)
│
├── security/                     ← SOPS secrets, Tailscale, firewall, hardening
├── boot/                         ← kernel, systemd-boot, zram, sysctl tuning
├── networking/                   ← NetworkManager, DNS, timezone
├── desktop/                      ← Hyprland + GNOME apps, GPU acceleration, Ly
├── home/                         ← Home Manager (shell, git, editors, fonts, services)
│
├── observability/                ← Prometheus, Grafana, Loki, Alloy, Falco, OTEL
├── recovery/                     ← health checks, rollback, self-heal
├── automation/                   ← GitOps reconciler, notifications
├── services/                     ← msmtp, bot, nginx, postgres, redis
├── developer/                    ← Go, Node, Python, Flutter toolchains
├── packages/                     ← CLI, desktop, system, user package sets
│
├── internal/                     ← Go source code (ivali CLI, Telegram bot)
├── cmd/                          ← Go entry points (ivali, bw-tui, ivali-bot)
├── scripts/                      ← Shell scripts (deploy, health, rollback, bot)
├── tests/                        ← NixOS smoke tests
└── opencode/                     ← AI context, architecture docs, troubleshooting
```

### Module System

Every top-level directory with a `default.nix` is auto-imported by `configuration.nix`
via `lib/auto-imports.nix`. No manual registration needed.

```
configuration.nix
  └── auto-imports.nix scans repo root
       ├── automation/      ✓ has default.nix → imported
       ├── boot/            ✓ has default.nix → imported
       ├── desktop/         ✓ has default.nix → imported (explicit)
       ├── home/            ✗ excluded (wired via flake.nix)
       ├── hosts/           ✗ excluded (pinned hardware config)
       ├── lib/             ✗ excluded (helper functions)
       ├── packages/        ✗ excluded (package sets, not modules)
       ├── scripts/         ✗ excluded (shell scripts)
       ├── secrets/         ✗ excluded (SOPS files)
       └── tests/           ✗ excluded (imported separately)
```

**To add a new domain module:**
1. Create `newdomain/default.nix`
2. It will be auto-discovered on next rebuild

**To add a module within an existing domain:**
1. Create `domain/submodule.nix`
2. Import it in `domain/default.nix` (for ordered imports)

**To skip a file from auto-import:**
- Prefix with `_` (e.g., `_common.nix`)

### Control Plane

```
deployment-health.timer (every 5 min)
  └── deployment-health.service
       └── scripts/deployment-health.sh
            └── on failure → gitops-reconciler.service
                              └── scripts/gitops-reconcile.sh
                                   ├── git pull + nix flake check
                                   ├── nix build + nixos-rebuild switch
                                   ├── post-deployment health check
                                   ├── on failure → scripts/rollback.sh
                                   └── Telegram + email notifications
```

### Repository Tree

```
.
├── .github/workflows/ci.yml        # GitHub Actions: validates mirror, posts status to GitLab
├── .sops.yaml                       # SOPS age configuration
├── AGENTS.md                        # AI agent context
├── DOCS.md                          # Auto-generated module docs (112 modules)
├── Makefile                         # Go build targets (ivali, bw-tui, ivali-bot)
├── README.md                        # This file
│
├── flake.nix                        # Flake: inputs, outputs, nixosConfigurations
├── configuration.nix                # Top-level NixOS module registry (auto-imports)
├── go.mod / go.sum                  # Go module definition
│
├── hosts/
│   ├── hosts.nix                    # Host registry (prague, testvm, default)
│   ├── hardware-configuration.nix   # Fallback hardware config
│   └── prague/
│       └── hardware-configuration.nix
│
├── lib/
│   ├── auto-imports.nix             # Domain module scanner
│   ├── hardware-detection.nix       # Hardware detection helpers
│   └── host-templates/
│       ├── default.nix
│       └── laptop.nix               # Generates full NixOS config from hostSpec
│
├── boot/
│   ├── kernel.nix                   # Linux 6.18 (LTS, pinned for RTL8821CE wifi), kernel params, AMD-specific
│   ├── loader.nix                   # systemd-boot configuration
│   ├── sysctl.nix                   # Kernel hardening (slab_nomerge, pti, etc.)
│   ├── zram.nix                     # zRAM with zstd (100% memory)
│   ├── plymouth.nix                 # Boot splash
│   └── tpm.nix                      # TPM support
│
├── security/
│   ├── firewall.nix                 # nftables, default deny, Tailscale-only SSH
│   ├── tailscale.nix                # Tailscale VPN + exit node
│   ├── hardening.nix                # Kernel/sysctl hardening stack
│   ├── apparmor.nix                 # AppArmor profiles (bot, CLI, reconciler)
│   ├── fail2ban.nix                 # SSHD + nginx jails
│   ├── sops.nix                     # SOPS secrets with age encryption
│   ├── sudo.nix                     # Sudo hardening (execWheelOnly, PTY required)
│   ├── scanning.nix                 # Daily security scans + Prometheus metrics
│   └── packages.nix                 # Security packages
│
├── networking/
│   ├── networkmanager.nix           # NetworkManager
│   └── time.nix                     # Timezone, NTP
│
├── desktop/
│   ├── default.nix                  # Desktop domain module
│   ├── gnome/
│   │   └── default.nix              # GNOME apps + services (system-wide)
│   ├── hyprland/
│   │   ├── default.nix              # Hyprland compositor module
│   │   ├── compositor.nix           # Hyprland + core desktop daemons
│   │   └── packages.nix             # Hyprland session packages
│   ├── login/
│   │   ├── default.nix
│   │   └── ly.nix                   # Ly TUI display manager
│   └── common/
│       ├── audio.nix                # PipeWire audio
│       ├── clipboard.nix            # Wayland clipboard utilities
│       ├── environment.nix          # Wayland session env vars
│       ├── gpu.nix                  # AMD GPU acceleration (amdgpu, Vulkan)
│       ├── packages.nix             # Shared desktop packages
│       ├── portals.nix              # xdg-desktop-portal (Hyprland + GTK)
│       └── theme.nix                # Active design-system theme
│
├── home/
│   ├── ivali.nix                    # User config entry point
│   ├── default.nix                  # Home Manager domain module
│   ├── fonts.nix                    # Nerd Fonts, MS Office fonts, Noto
│   ├── theming.nix                  # GTK theme
│   ├── shell/
│   │   ├── default.nix              # Shell domain module (auto-imports children)
│   │   ├── aliases/                 # Domain-grouped shell aliases
│   │   │   ├── git.nix              # Git aliases (gpall, gco, gaa, etc.)
│   │   │   ├── nix.nix              # Nix aliases (rebuild, switch, etc.)
│   │   │   ├── navigation.nix       # cd, ls, tree aliases
│   │   │   ├── utilities.nix        # General utilities
│   │   │   ├── development.nix      # Dev aliases
│   │   │   └── ivali.nix            # CLI aliases
│   │   ├── bitwarden/               # Bitwarden CLI integration
│   │   │   ├── cache.nix, completion.nix, env.nix
│   │   ├── core/                    # Zsh, bash, history, completion, keybindings
│   │   │   ├── prompt.nix           # Powerlevel10k prompt
│   │   │   └── startup/             # Startup scripts
│   │   │       ├── 10-dashboard.nix # Welcome dashboard
│   │   │       ├── 20-completion.nix
│   │   │       ├── 30-keybindings.nix
│   │   │       └── 50-options.nix
│   │   ├── integrations/            # Direnv, FZF, Zoxide, Atuin
│   │   └── tools/                   # Bat, Btop, Eza, Fastfetch, packages
│   ├── git/
│   │   ├── git.nix                  # Git config, delta, aliases
│   │   ├── delta.nix                # Delta diff viewer (gruvbox)
│   │   └── packages.nix             # git-lfs, gitui, lazygit
│   ├── hyprland/
│   │   ├── default.nix              # Hyprland window manager config
│   │   ├── hypr/                    # Keybindings, rules, monitors, animations
│   │   ├── waybar/                  # Waybar status bar + per-module configs
│   │   ├── rofi/                    # Rofi application launcher
│   │   ├── swaync/                  # SwayNC notification center
│   │   ├── wlogout/                 # Wlogout power menu
│   │   ├── gnome/                   # GNOME app user settings (dconf)
│   │   └── ...                      # hyprlock, hypridle, screenshot, clipboard, ...
│   ├── terminal/
│   │   └── kitty.nix                # Kitty terminal (Gruvbox theme)
│   ├── editors/
│   │   └── zed.nix                  # Zed editor with extensions
│   ├── environment/
│   │   ├── variables.nix            # Session variables (SOPS_AGE_KEY_FILE, etc.)
│   │   ├── xdg.nix                  # XDG directory paths
│   │   ├── mime.nix                 # MIME type default applications
│   │   ├── packages.nix             # User packages
│   │   ├── session.nix              # Session init
│   │   └── locale.nix               # Locale
│   ├── services/
│   │   └── auto-format.nix          # Auto-format .nix files on change
│   └── identity/
│       └── default.nix              # User identity
│
├── observability/
│   ├── options.nix                  # Observability options (enable flag)
│   ├── prometheus.nix               # Prometheus metrics collection
│   ├── grafana.nix                  # Grafana dashboards + data sources
│   ├── loki.nix                     # Loki log aggregation
│   ├── alloy.nix                    # Grafana Alloy log collection
│   ├── falco.nix                    # Falco security event detection
│   ├── otel.nix                     # OpenTelemetry collector
│   ├── alertmanager.nix             # Alertmanager routing to Telegram
│   ├── alerting.nix                 # Prometheus alerting rules
│   ├── health-endpoint.nix          # JSON health endpoint (11 checks)
│   ├── dashboards.nix               # Auto-provisioned Grafana dashboards
│   ├── nixos-exporter.nix           # NixOS Prometheus exporter
│   ├── journald.nix                 # Systemd journal persistence
│   ├── retention.nix                # Data retention policies
│   ├── slo.nix                      # SLO tracking + error budget alerts
│   └── packages.nix                 # Observability packages
│
├── automation/
│   ├── options.nix                  # GitOps options
│   ├── gitops-reconciler.nix        # GitOps reconciliation loop + timer
│   └── common.nix                   # Shared constants
│
├── recovery/
│   ├── deployment-health.nix        # Health check timer + service
│   └── rollback.nix                 # Self-heal rollback on failure
│
├── services/
│   ├── bot/
│   │   ├── ivali-bot.nix            # Bash bot NixOS service
│   │   ├── ivali-bot-go.nix         # Go bot NixOS service
│   │   └── ci-notify.nix            # CI notification service
│   ├── msmtp/                       # Email relay (SMTP via Office365)
│   │   ├── config.nix
│   ├── nginx/                       # Reverse proxy (localhost-only)
│   │   ├── config.nix, options.nix
│   ├── postgres/                    # PostgreSQL database
│   │   ├── config.nix, options.nix
│   └── redis/                       # Redis key-value store
│       ├── options.nix, service.nix
│
├── developer/
│   ├── languages.nix                # Go, Node 22, Python 3.13, Flutter/Dart
│   └── shell.nix                    # Developer shell defaults
│
├── ssh/
│   ├── daemon.nix                   # SSH daemon (Tailscale-only, no password)
│   ├── client.nix                   # SSH client config
│   └── options.nix                  # SSH options
│
├── ci/
│   ├── gitlab-runner.nix            # Self-hosted GitLab Runner
│   └── ci-deploy.nix                # CI deploy service
│
├── packages/
│   ├── cli/default.nix              # CLI tools (bat, ripgrep, fzf, jq, etc.)
│   ├── desktop/default.nix          # GUI apps (Firefox, Obsidian, VLC, etc.)
│   ├── system/default.nix           # System-wide packages
│   └── user/default.nix             # User-only packages
│
├── system/
│   ├── nix.nix                      # Nix daemon config
│   ├── users.nix                    # System users
│   └── state.nix                    # NixOS state version
│
├── i18n/
│   └── locale.nix                   # Locale settings
│
├── storage/
│   ├── btrfs.nix                    # BTRFS config
│   └── tmpfs.nix                    # Tmpfs mounts
│
├── virtualization/
│   └── docker.nix                   # Docker + weekly auto-prune
│
├── cmd/
│   ├── ivali/main.go                # Go CLI entry point
│   ├── bw-tui/main.go               # Bitwarden TUI entry point
│   └── ivali-bot/main.go            # Go Telegram bot entry point
│
├── internal/
│   ├── commands/                    # CLI commands (20+ files)
│   │   ├── root.go, status.go, doctor.go, dashboard.go
│   │   ├── health.go, health_checks.go, scan.go, verify.go
│   │   ├── explain.go, graph.go, suggest.go, metrics.go
│   │   ├── bootstrap.go, bootstrap_host.go
│   │   ├── deploy.go, rebuild.go, reconcile.go, update.go
│   │   ├── docs.go, completion.go, extract.go
│   │   └── progress.go
│   ├── dashboard/                   # Bubble Tea TUI dashboard (6 tabs)
│   ├── telegram/                    # Go Telegram bot
│   │   ├── bot.go, api.go, auth.go, config.go, runner.go
│   │   └── handlers/
│   │       ├── commands.go          # System/status commands (15+)
│   │       ├── desktop_commands.go  # Desktop control (12+)
│   │       ├── git_commands.go      # Git/GitHub/GitLab
│   │       └── system_commands.go   # Nix/shell/user management
│   ├── config/                      # Config loading + tests
│   ├── graph/                       # Module import graph + tests
│   ├── parser/                      # Nix file parser + tests
│   ├── scanner/                     # Repository scanner + tests
│   ├── repository/                  # Repository abstraction + tests
│   ├── template/                    # Code generation templates
│   │   ├── host.go, domain.go, service.go, shell.go
│   │   ├── editor.go, packages.go, generate.go
│   ├── terminal/                    # Terminal UI helpers + tests
│   ├── bitwarden/                   # Bitwarden CLI client (cache, clipboard, TUI)
│   ├── logger/                      # Structured logging + tests
│   └── wizard/                      # Interactive setup wizard
│
├── scripts/
│   ├── install-fresh-nixos.sh       # Fresh NixOS install script
│   ├── bot/
│   │   ├── bot.sh                   # Bash bot main loop
│   │   ├── config.sh                # Bot configuration
│   │   ├── commands/                 # 46 bash bot command scripts
│   │   │   ├── status.sh, health.sh, deploy.sh, rollback.sh
│   │   │   ├── screenshot.sh, volume.sh, brightness.sh
│   │   │   ├── open.sh, apps.sh, firefox.sh, clipboard.sh
│   │   │   ├── run.sh, git_cmd.sh, gitlab_cmd.sh, nix_cmd.sh
│   │   │   ├── generations.sh, store.sh, gc.sh, doctor.sh
│   │   │   ├── scan.sh, security.sh, metrics.sh, processes.sh
│   │   │   ├── windows.sh, workspace.sh, monitoron.sh
│   │   │   ├── reboot.sh, shutdown.sh, update.sh, cancel.sh
│   │   │   ├── adduser.sh, rmuser.sh, users.sh, backup.sh
│   │   │   ├── log.sh, notify_cmd.sh, pkg.sh, speedtest.sh
│   │   │   └── _template.sh
│   │   ├── lib/                     # Bot library functions
│   │   │   ├── core.sh, auth.sh, telegram.sh, system.sh
│   │   │   ├── nix.sh, desktop.sh, gitlab.sh, pending.sh
│   │   │   ├── app_registry.sh, registry.sh
│   │   └── desktop/                 # Desktop integration
│   │       ├── aliases.sh, discovery.sh, urls.sh
│   ├── deployment-health.sh         # Health check script
│   ├── gitops-reconcile.sh          # GitOps reconciliation script
│   ├── rollback.sh                  # Generation rollback script
│   ├── ci-deploy.sh                 # CI deploy script
│   ├── notify.sh                    # Telegram + email notification script
│   ├── rotate-sops-key.sh           # SOPS key rotation
│   ├── sops-setup.sh                # SOPS initial setup
│   ├── gitlab-runner-health.sh      # GitLab Runner health check
│   └── gitlab-runner-reconcile.sh   # GitLab Runner reconciliation
│
├── tests/
│   ├── laptop-smoke.nix             # NixOS VM smoke test
│   ├── security-smoke.nix           # Security config test
│   ├── observability-smoke.nix      # Observability test
│   ├── services-smoke.nix           # Services test
│   ├── home-manager-smoke.nix       # Home Manager test
│   ├── automation-smoke.nix         # Automation test
│   ├── bot-integration.nix          # Bot integration test
│   ├── bot-desktop-smoke.sh         # Bot desktop smoke test
│   └── bitwarden-smoke.nix          # Bitwarden test
│
├── secrets/
│   ├── tailscale.yaml               # Tailscale auth key, Grafana secret
│   ├── telegram.yaml                # Bot token, chat ID, email
│   ├── smtp.yaml                    # SMTP credentials (Office365)
│   ├── gitlab-runner.yaml           # Runner registration token
│   ├── gitlab.yaml                  # GitLab API token
│   ├── bitwarden.yaml               # Bitwarden secrets
│   └── hosts/prague.yaml            # Per-host secrets
│
└── opencode/                        # AI context + troubleshooting docs
    ├── architecture.md              # Architecture deep-dive
    ├── deployment.md                # Deployment procedures
    ├── hosts.md                     # Host documentation
    ├── modules.md                   # Module catalog
    ├── troubleshooting.md           # Common issues + fixes
    └── tailscale-mesh.md            # Tailscale network topology
```

---

## Installation

### Fresh Install

Start from a clean NixOS GNOME installation. Log in as your normal user (not root):

```bash
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#curl --command bash -c \
  'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
```

The installer will:
1. Enable `nix-command` and `flakes` in the user Nix config
2. Clone this repository to `~/nixos-infrastructure`
3. Copy `/etc/nixos/hardware-configuration.nix` to `hosts/hardware-configuration.nix`
4. Install a Git pre-commit hook for auto-formatting
5. Run `nix fmt`
6. Build and switch to `.#prague`

After the switch completes, reboot:

```bash
sudo reboot
```

Commit and push the generated hardware file:

```bash
cd ~/nixos-infrastructure
git add hosts/prague.nix hosts/prague/hardware-configuration.nix secrets/hosts/prague.yaml
git commit -m "chore: add hardware configuration for prague"
git push
```

### Verify Installation

```bash
ivali status          # Repository state summary
ivali doctor          # Full health check
tailscale status      # Tailscale VPN status
ssh -T git@gitlab.com # Verify GitLab SSH access
```

---

## Daily Workflow

### NixOS Commands

```bash
rebuild          # nixos-rebuild switch --flake .#prague
test-rebuild     # dry build without switching
check            # nix flake check --print-build-logs
fmt              # nix fmt (also runs on save and pre-commit)
update           # nix flake update
clean            # nix store gc
```

### Go CLI (`ivali`)

| Command | Description |
|---------|-------------|
| `ivali status` | Repository state: branch, hosts, modules, domains, health |
| `ivali doctor` | Full health check (supports `--fix`, `--aggressive`) |
| `ivali dashboard` | Interactive TUI (Bubble Tea, 6 tabs) |
| `ivali explain <mod>` | Module details: purpose, imports, options |
| `ivali graph tree` | Module import hierarchy |
| `ivali graph deps` | Flat dependency list |
| `ivali bootstrap host` | Generate new host from template |
| `ivali bootstrap module` | Generate new module from template |
| `ivali bootstrap service` | Generate new service module |
| `ivali docs` | Generate DOCS.md from module headers |
| `ivali suggest` | Improvement recommendations |
| `ivali metrics` | Repository metrics (supports `--json`) |
| `ivali verify` | Full verification suite |
| `ivali deploy` | Remote deployment via `nixos-rebuild` |
| `ivali reconcile` | GitOps reconciliation |
| `ivali update` | Pull + flake update |
| `ivali scan` | Force fresh repository scan |
| `ivali extract shell` | Analyze shell configuration |

### Go Telegram Bot

```bash
ivali-bot             # Start the Telegram bot (systemd service: ivali-bot.service)
```

---

## Host Management

Hosts are defined as per-host spec files (`hosts/<name>.nix`), auto-discovered
by `hosts/hosts.nix` (the aggregator). The flake generates `nixosConfigurations`
dynamically from this registry.

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
  config = {
    ivali.desktop.gnome.enable = true;
    ivali.observability.enable = lib.mkForce false;
  };
};
```

### Adding a New Host

1. Create `hosts/<name>.nix` with the host spec (see `hosts/default.nix` for template)
2. Run `ivali bootstrap host <name>` to generate hardware config and secrets
3. Run `nixos-rebuild switch --flake .#<name>`

---

## Security

| Layer | Technology |
|-------|-----------|
| Kernel | `slab_nomerge`, `init_on_alloc/free`, `pti=on`, `vsyscall=none`, `randomize_kstack_offset=on` |
| Sysctl | `kptr_restrict=2`, `dmesg_restrict=1`, `unprivileged_bpf_disabled=1`, `perf_event_paranoid=3` |
| Firewall | nftables, default deny inbound, Tailscale-only SSH, ping blocked |
| SSH | Password disabled, root disabled, X11 off, Tailscale interface only |
| Sudo | `execWheelOnly`, 5min timeout, 3 attempts, PTY required |
| AppArmor | Enabled with profiles for bot, CLI, reconciler |
| Fail2Ban | SSHD + nginx jails |
| Secrets | SOPS + age encryption |
| Scanning | Daily security scans with Prometheus metrics |

---

## Observability

| Component | Purpose | Port |
|-----------|---------|------|
| **Prometheus** | Metrics collection + alerting | 9090 |
| **Grafana** | Dashboards + visualization | 3000 |
| **Loki** | Log aggregation | 3100 |
| **Alloy** | Log collection + forwarding | — |
| **Falco** | Security event detection | — |
| **OTEL** | OpenTelemetry traces + metrics | 4317/4318 |
| **Alertmanager** | Alert routing | 9093 |
| **Health endpoint** | JSON health checks (11 checks) | 9100 |
| **NixOS exporter** | NixOS-specific Prometheus metrics | 9101 |

All services bind to localhost. Access via SSH tunnel:

```bash
ssh -L 80:localhost:80 prague
# Grafana:     http://localhost/grafana/
# Prometheus:  http://localhost/prometheus/
# Loki:        http://localhost/loki/
# Health:      http://localhost/health
```

### Alerting

Prometheus alerting rules for: disk space, high CPU/memory, failed services,
Tailscale key expiry, SLO budget burn. Alerts routed to Telegram via Alertmanager.

### Retention

| Data | Retention |
|------|-----------|
| Prometheus metrics | 15 days |
| Loki logs | 7 days |
| Systemd journal | Persistent |

---

## Telegram Bot

A Go-based Telegram bot (`ivali-bot`) for full remote control of the system.

### Commands

| Category | Commands |
|----------|----------|
| **System** | `/status`, `/health`, `/top`, `/disk`, `/processes`, `/log`, `/metrics`, `/store` |
| **Operations** | `/deploy`, `/rollback`, `/reboot`, `/shutdown`, `/update`, `/gc`, `/generations` |
| **Desktop** | `/open`, `/apps`, `/firefox`, `/screenshot`, `/clipboard`, `/volume`, `/mute`, `/brightness`, `/windows`, `/workspace`, `/desktop_power`, `/monitoron` |
| **Admin** | `/run`, `/nix`, `/pkg`, `/scan`, `/doctor`, `/security`, `/speedtest`, `/notify` |
| **Git** | `/git`, `/github`, `/gitlab` |
| **User** | `/users`, `/adduser`, `/rmuser` |
| **Help** | `/help`, `/menu`, `/start`, `/cancel` |

### Access Control

| Role | Permissions |
|------|-------------|
| **owner** | Full access + user management |
| **admin** | Deploy, reboot, rollback, shutdown, update, gc, run, nix |
| **user** | Status, health, metrics, log, scan, doctor, security, generations, store |
| **guest** | Status and help only |

---

## CI/CD

### CI model

GitLab is the single source of truth and push-mirrors to GitHub — no code
originates on GitHub. Deployment is driven by the GitOps reconciler, **not** CI.
GitHub Actions only validates the mirror and reports back to GitLab.

### GitHub Actions (mirror validator)

Runs on portable GitHub-hosted runners (`ubuntu-latest`) via the Nix installer
action — no self-hosted GitLab runner required. Jobs:

| Job | What it does |
|-----|--------------|
| `secret-scan` | gitleaks `detect` (no-git source scan); fails on committed secrets; allowlists `.age`/`secrets`/`hardware-configuration`/`flake.lock` |
| `go-build` | `CGO_ENABLED=0 go build ./...` (cross-compiles without a C toolchain) |
| `go-test` | `CGO_ENABLED=1 go test -race ./...` |
| `nix-format` | `nix fmt` then `git diff --exit-code` (avoids the buggy `nix fmt --check`) |
| `nixos-checks` | `nix build` of every `nixosConfigurations` (dry build; `continue-on-error`) |
| `gitlab-status` | posts the combined status back to GitLab via the GitLab API (only when `GITLAB_TOKEN` is set) |

---

## Secrets

SOPS-encrypted with age. Files in `secrets/`:

| File | Contents |
|------|----------|
| `tailscale.yaml` | Auth key, Grafana secret |
| `telegram.yaml` | Bot token, chat ID, email |
| `smtp.yaml` | SMTP credentials (Office365) |
| `gitlab-runner.yaml` | Runner registration token |
| `gitlab.yaml` | GitLab API token |
| `hosts/<name>.yaml` | Per-host secrets |

Runtime secrets at `/run/secrets/` (symlinked by sops-nix).

---

## Home Manager

| Module | What It Configures |
|--------|-------------------|
| `shell/` | Zsh, Powerlevel10k, FZF, zoxide, direnv, aliases (git, nix, navigation, etc.) |
| `shell/bitwarden/` | Bitwarden CLI integration with fzf search |
| `git/` | Delta diff, git-lfs, gitui, lazygit |
| `hyprland/` | Hyprland config, Waybar, Rofi, SwayNC, Wlogout, GNOME app settings |
| `terminal/kitty.nix` | Kitty terminal (Gruvbox theme) |
| `environment/mime.nix` | XDG MIME default applications |
| `editors/zed.nix` | Zed editor with Nix/Python/Go/TS extensions |
| `environment/` | Session variables, XDG paths, packages |
| `fonts.nix` | Nerd Fonts, MS Office fonts, Noto |
| `services/` | Auto-format .nix files on change |
| `theming.nix` | GTK theme |

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

Options in `options.nix`, implementation in sibling files:

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

## Safety Notes

- Use `nixos-rebuild boot` (not `switch`) when the display might drop
- Observability stack is currently disabled on `prague` (laptop hardware limit)
- Tailscale DNS/routes default to off during setup
- Grafana, Prometheus, Loki are localhost-only unless explicitly exposed
- GitOps reconciler uses a lock file — avoid manual `nixos-rebuild` during reconciliation
- SOPS secrets fail closed — features requiring secrets won't activate until age key is installed
- The Telegram bot requires role configuration with `/adduser` after initial setup

## License

MIT — see [LICENSE](LICENSE).
