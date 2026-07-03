# Module Catalog

## NixOS Domain Modules

| Domain | Location | Purpose | Key Files |
|--------|----------|---------|-----------|
| **automation** | `automation/` | GitOps reconciler, Telegram bot, CI | `gitops-reconciler.nix`, `common.nix`, `options.nix` |
| **boot** | `boot/` | Kernel, bootloader, sysctl tuning | `kernel.nix`, `loader.nix`, `sysctl.nix`, `zram.nix` |
| **ci** | `ci/` | GitLab Runner, CI deployment | `gitlab-runner.nix`, `ci-deploy.nix` |
| **cloud** | `cloud/` | Cloud provider stubs | `aws/`, `hetzner/`, `digitalocean/` |
| **desktop** | `desktop/` | GNOME, GPU acceleration | `gnome-lean.nix`, `gpu.nix` |
| **developer** | `developer/` | Language toolchains | `languages.nix`, `shell.nix` |
| **i18n** | `i18n/` | Locale, internationalization | `locale.nix` |
| **networking** | `networking/` | NetworkManager, DNS, time | `networkmanager.nix`, `time.nix` |
| **observability** | `observability/` | Monitoring, logging, security | `prometheus.nix`, `grafana.nix`, `loki.nix`, `alloy.nix`, `falco.nix` |
| **packages** | `packages/` | System, CLI, desktop, user pkgs | `cli/`, `desktop/`, `system/`, `user/` |
| **recovery** | `recovery/` | Health checks, rollback, self-heal | `deployment-health.nix`, `rollback.nix` |
| **security** | `security/` | SOPS, Tailscale, firewall, hardening | `sops.nix`, `tailscale.nix`, `firewall.nix`, `hardening.nix` |
| **services** | `services/` | msmtp, bot, nginx, postgres, redis | `msmtp/`, `bot/`, `nginx/` |
| **ssh** | `ssh/` | SSH daemon and client | `default.nix`, `client.nix` |
| **storage** | `storage/` | BTRFS, LUKS encryption | `btrfs.nix`, `encryption.nix` |
| **system** | `system/` | Users, Nix config, state | `users.nix`, `nix.nix`, `state.nix` |
| **virtualization** | `virtualization/` | Docker, VMs | `docker.nix` |

## Home Manager Modules

| Module | Location | Purpose |
|--------|----------|---------|
| **identity** | `home/identity/` | User identity (name, home directory) |
| **shell** | `home/shell/` | Zsh, bash, aliases, tools (bat, eza, fzf, zoxide) |
| **git** | `home/git/` | Git config, delta, packages |
| **editors** | `home/editors/` | Zed editor with extensions |
| **environment** | `home/environment/` | Locale, packages, session, XDG |
| **services** | `home/services/` | Auto-format service |
| **fonts** | `home/fonts/` | Nerd Fonts, MS Office fonts, CJK |

## Go CLI (`internal/`)

| Package | Purpose |
|---------|---------|
| `commands/` | All CLI commands (status, doctor, dashboard, etc.) |
| `app/` | Application context |
| `config/` | TOML config loading |
| `scanner/` | Repository scanning |
| `parser/` | Nix file parsing |
| `repository/` | Repository detection, health checks |
| `graph/` | Module dependency graph |
| `terminal/` | Rich terminal rendering |
| `dashboard/` | Interactive TUI |
| `template/` | Code generators |
| `logger/` | Structured logging |

## Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `install-fresh-nixos.sh` | Universal bootstrap for new NixOS installs |
| `deployment-health.sh` | Comprehensive system health check |
| `gitops-reconcile.sh` | Pull + rebuild + verify loop |
| `rollback.sh` | Revert to previous NixOS generation |
| `notify.sh` | Telegram + email notifications |
| `gitlab-runner-health.sh` | GitLab Runner health monitoring |
| `bot/` | Telegram bot (30+ commands) |

## Telegram Bot Commands

### Infrastructure
`/status` `/health` `/deploy` `/rollback` `/update` `/reboot` `/shutdown` `/cancel`

### Desktop Control
`/open` `/apps` `/screenshot` `/volume` `/mute` `/unmute` `/brightness` `/clipboard`

### System
`/processes` `/windows` `/focus` `/close` `/workspace` `/lock` `/logout` `/suspend` `/hibernate`

### Development
`/run` `/git` `/gitlab` `/nix` `/log`
