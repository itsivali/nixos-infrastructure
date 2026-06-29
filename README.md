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
- [Telegram Notifications](#telegram-notifications)
- [Feature Deep Dives](#feature-deep-dives)
  - [Desktop: Lean GNOME + AMD](#desktop-lean-gnome--amd)
  - [Security: Defence in Depth](#security-defence-in-depth)
  - [Observability Stack](#observability-stack)
  - [Boot & Kernel Tuning](#boot--kernel-tuning)
  - [Networking & Tailscale](#networking--tailscale)
  - [Developer Toolchain](#developer-toolchain)
  - [Home Manager User Config](#home-manager-user-config)
- [Repository Layout](#repository-layout)
- [Package Management](#package-management)
- [GitLab CI/CD](#gitlab-cicd)
- [Secrets Management](#secrets-management)
- [Roadmap](#roadmap)
- [Safety Notes](#safety-notes)

---

## Features

| Area | What's Included |
|------|----------------|
| **Desktop** | Lean GNOME on Wayland, GDM, AMD GPU acceleration, power management, Bluetooth |
| **Kernel** | `linuxPackages_latest`, custom sysctl hardening, zRAM with zstd compression |
| **Security** | nftables firewall, AppArmor, fail2ban, Tailscale-only SSH, kernel hardening, hardened sudo |
| **Networking** | NetworkManager, systemd-resolved (DoT), Tailscale with exit node, BBR congestion control |
| **SSH** | Passwordless, Tailscale-only, ShellFish-compatible, GitLab key auth |
| **Developer** | Node 22, Python 3.13, Go, `tsx`, Flutter/Dart, Nix formatter |
| **Virtualization** | Docker with weekly auto-prune |
| **Observability** | Grafana, Prometheus, Loki, Grafana Alloy, Falco, OTEL collector, journald persistence |
| **CI/CD** | GitLab pipeline with flake checks, binary cache push, SBOM generation, secret detection |
| **GitOps** | Self-healing deployment health monitor, automated reconciler, rollback on failure |
| **Notifications** | Telegram bot + email alerts for build, deploy, health, and rollback events |
| **Secrets** | SOPS-encrypted secrets with age (Tailscale, SMTP, Telegram, Grafana, GitLab Runner) |
| **Home Manager** | Modular zsh + Powerlevel10k, FZF, zoxide, direnv, Git config (delta), Zed editor, Bitwarden vault, systemd auto-format |
| **Storage** | BTRFS, encrypted swap, aggressive zRAM (100% memory, zstd) |
| **Packages** | Separate CLI and desktop package sets, system-wide vs user-only install surfaces |

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

## Telegram Notifications

The system uses a dedicated Telegram bot for real-time infrastructure alerts.

### How It Works

- Bot token stored in `secrets/telegram.yaml` (SOPS-encrypted with age)
- Notification script `scripts/notify.sh` sends HTTPS POST to `api.telegram.org`
- Chat ID: configured per-host in `automation/_common.nix`

### What Triggers Notifications

| Event | Channel |
|-------|---------|
| GitOps reconcile success | Telegram + Email |
| GitOps reconcile failure | Telegram + Email |
| Deployment health check failure | Telegram + Email |
| Self-heal rollback success | Telegram + Email |
| Self-heal rollback failure | Telegram + Email |
| Build failure (CI) | Telegram + Email |

### Configuration

```nix
# automation/_common.nix
notifications.telegram.chatId = "7724444807";
```

Secrets file (`secrets/telegram.yaml`):

```yaml
telegram_bot_token: <encrypted-bot-token>
telegram_chat_id: <encrypted-chat-id>
notify_email: <encrypted-email>
```

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
| **Sysctl hardening** | `kptr_restrict=2`, `dmesg_restrict=1`, `unprivileged_bpf_disabled=1`, `kexec_load_disabled=1`, `perf_event_paranoid=3`, `sysrq=0` |
| **Firewall** | nftables (not iptables), default deny inbound, Tailscale-only SSH, ping blocked, refuse + packet logging |
| **AppArmor** | Enabled with system profiles |
| **Fail2Ban** | SSHD jail, 3 retries, 1h ban (incremental up to 168h), 10 min find window |
| **Tailscale** | All SSH access restricted to `tailscale0` interface |
| **SSHD** | Password auth disabled, root login disabled, X11 forwarding off, keyboard-interactive auth off |
| **Sudo** | `execWheelOnly`, 5 min timeout, 3 attempts, PTY required, full logging |
| **Kernel module lockdown** | Module locking enabled, kernel image protected |
| **SOPS secrets** | All credentials encrypted with age — Tailscale, SMTP, Telegram, Grafana, GitLab Runner |
| **Security auditing** | `aide`, `audit`, `lynis`, audit logs persisted |

### Observability Stack

All services are bound to **localhost only** (127.0.0.1) by default.

| Service | Port | Purpose |
|---------|------|---------|
| **Grafana** | 3000 | Dashboards & visualisation |
| **Prometheus** | 9090 | Metrics collection & alerting |
| **Loki** | 3100 | Log aggregation |
| **Grafana Alloy** | — | Journald → Loki log forwarder |
| **Falco** | — | Runtime security threat detection |
| **OTEL Collector** | — | OpenTelemetry traces + metrics pipeline |
| **Node Exporter** | — | System metrics |

**Data flow:**
```
systemd journal ─→ Grafana Alloy ─→ Loki ─→ Grafana
                                        ↗
Prometheus ─→ self + node exporter ────┘
```

**Retention:**
- Prometheus: 15 days
- Loki: 7 days
- Journald: persistent, compressed

Grafana is provisioned with Prometheus (default) and Loki data sources out of
the box — no manual setup required.

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

### Networking & Tailscale

- **NetworkManager** with systemd-resolved
- **DNS:** Cloudflare (`1.1.1.1`) + Quad9 (`9.9.9.9`) with DNS-over-TLS (opportunistic)
- **DNSSEC:** allow-downgrade
- **mDNS:** enabled, LLMNR: disabled
- **Timezone:** Africa/Nairobi
- **Tailscale:** enabled with exit node advertising, but conservative defaults:
  - `--accept-dns=false` — your DNS stays untouched
  - `--accept-routes=false` — no unexpected routing
  - SSH access restricted to `tailscale0` interface
- **Split DNS:** timer-based service configures `resolvectl` for tailnet domain

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
├── observability/         # Grafana, Prometheus, Loki, Alloy, Falco, OTEL
├── packages/              # CLI, desktop, system, and user package sets
├── recovery/              # Deployment health check, self-heal rollback
├── scripts/               # Install bootstrap, admin, and notification scripts
├── secrets/               # SOPS-encrypted secret files (age)
├── security/              # Firewall, Tailscale SSH, hardening, fail2ban, SOPS
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

SOPS is configured but disabled at first install so `nixos-rebuild switch` does
not fail before the age key is in place. After installing the key, enable:

```nix
ivali.secrets.enable = true;
```

---

## Roadmap

### In Progress

- [ ] **Cloud provisioning** — AWS EC2, Hetzner Cloud, DigitalOcean droplet
      modules (stubs exist in `cloud/`)
- [ ] **Web server** — Nginx reverse proxy (stub in `services/nginx/`)
- [ ] **Database** — PostgreSQL module (stub in `services/postgres/`)
- [ ] **Cache layer** — Redis module (stub in `services/redis/`)
- [ ] **BTRFS tuning** — Filesystem performance and snapshot management
      (stub in `storage/btrfs.nix`)
- [ ] **Disk encryption** — LUKS configuration (stub in `storage/encryption.nix`)

### Planned

- [ ] **Fleet expansion** — Multi-host support (add new hosts by dropping a
      `hosts/<name>.nix` and setting `hostName` in flake.nix)
- [ ] **Atuin shell history** — Synced history across hosts
- [ ] **Prometheus alerting** — Alert rules via Telegram/email
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
