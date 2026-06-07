# nixos-infrastructure

Personal NixOS infrastructure for the `prague` laptop, managed with Nix flakes,
Home Manager, GitLab CI/CD, SOPS-ready secrets, lean GNOME, Tailscale, LocalSend,
and a local observability stack.

This repository is designed for a fresh NixOS GNOME install that does not yet
have Git or flakes enabled. The bootstrap script enables what it needs, clones
the repo, imports the machine hardware configuration, validates the flake, and
switches the system.

## What This Builds

- NixOS host: `prague`
- Desktop: lean GNOME, stripped of heavier default GNOME applications
- Kernel: `linuxPackages_zen` for desktop responsiveness
- Memory: zram enabled with aggressive swappiness tuning
- Networking: NetworkManager, systemd-resolved, hardened SSH
- Firewall: inbound allow-list, outbound internet preserved, LocalSend open
- Tailscale: enabled, SSH capable, exit-node advertising on, no accepted DNS/routes by default
- Developer stack: Docker, Node, `tsx`, Python, Flutter, Dart, VS Code
- Home Manager: user config routed through `home/ivali.nix`
- Monitoring: Grafana, Prometheus, node exporter, Loki, Grafana Alloy
- Security: fail2ban, AppArmor, auditd, journald persistence
- CI/CD: GitLab pipeline for flake checks, system builds, binary cache publishing, SBOM generation, and deployment hooks

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

## Daily Workflow

Open this repo in VS Code:

```bash
code ~/nixos-infrastructure
```

Or use the shell alias:

```bash
edit-config
```

Rebuild after making a change:

```bash
rebuild
```

Test without making the generation permanent:

```bash
test-rebuild
```

Run checks manually:

```bash
nix flake check --print-build-logs
```

Format manually:

```bash
nix fmt
```

Nix files are also formatted automatically in two places:

- a Home Manager user service watches `~/nixos-infrastructure`
- a Git pre-commit hook formats staged `.nix` files before commit

## Monitoring

The local monitoring stack is enabled by `observability/default.nix`.

Services are bound to localhost by default:

- Grafana: <http://localhost:3000>
- Prometheus: <http://localhost:9090>
- Loki: <http://localhost:3100>

Initial Grafana login:

```text
username: admin
password: admin
```

Change the password after first login.

Grafana is provisioned with two data sources:

- `Prometheus` for metrics
- `Loki` for logs

Prometheus scrapes:

- Prometheus itself
- local node exporter

Grafana Alloy reads the systemd journal and forwards logs to Loki.

Useful commands:

```bash
systemctl status grafana.service
systemctl status prometheus.service
systemctl status loki.service
systemctl status alloy.service
systemctl status prometheus-node-exporter.service || systemctl status prometheus-node.service
```

View logs:

```bash
journalctl -u grafana.service -f
journalctl -u prometheus.service -f
journalctl -u loki.service -f
journalctl -u alloy.service -f
```

Quick checks:

```bash
curl http://localhost:3000/api/health
curl http://localhost:9090/-/ready
curl http://localhost:3100/ready
```

In Grafana:

1. Open <http://localhost:3000>.
2. Log in with `admin` / `admin`.
3. Go to `Connections -> Data sources`.
4. Confirm `Prometheus` and `Loki` are present.
5. Go to `Explore`.
6. Select `Prometheus` and query:

```promql
up
```

7. Select `Loki` and query:

```logql
{job="systemd-journal"}
```

Official docs:

- Grafana getting started: <https://grafana.com/docs/grafana/latest/getting-started/>
- Prometheus getting started: <https://prometheus.io/docs/tutorials/getting_started/>
- Loki configuration: <https://grafana.com/docs/loki/latest/configuration/>
- Alloy documentation: <https://grafana.com/docs/alloy/latest/>

## LocalSend

LocalSend is installed as a system application. The firewall explicitly opens:

- TCP `53317`
- UDP `53317`

That allows laptop-to-phone discovery and transfer on the local network.

If discovery does not work:

```bash
systemctl status NetworkManager.service
sudo nft list ruleset | grep 53317
```

Make sure the laptop and phone are on the same LAN/VLAN and that the Wi-Fi
network does not block client-to-client traffic.

## Tailscale

Tailscale is enabled, but intentionally conservative so normal internet keeps
working while the tailnet is being configured.

Defaults:

- `--accept-dns=false`
- `--accept-routes=false`
- Prague advertises itself as an exit node
- no blanket trust for `tailscale0`

Authenticate manually:

```bash
sudo tailscale up --ssh
```

Check status:

```bash
tailscale status
tailscale netcheck
```

Only enable accepted routes once you want this machine to use routes advertised
by other tailnet nodes:

```nix
ivali.tailscale = {
  acceptRoutes = true;
};
```

## Repository Layout

```text
.
├── boot/                  # Kernel, bootloader, zram, sysctl tuning
├── ci/                    # Native NixOS GitLab Runner module
├── desktop/               # Lean GNOME module
├── developer/             # DevOps and programming toolchains
├── home/                  # Home Manager modules; entry point is ivali.nix
├── hosts/                 # Host-specific config and generated hardware config
├── networking/            # DNS, SSH, NetworkManager, timezone
├── observability/         # Grafana, Prometheus, Loki, Alloy, auditd
├── packages/              # GUI, terminal, system, and user package sets
├── security/              # Firewall, Tailscale, hardening, fail2ban
├── scripts/               # Fresh install bootstrap
└── tests/                 # NixOS smoke tests
```

## Package Management

GUI apps and terminal apps are intentionally separated under `packages/`.

Add GUI desktop applications here:

```text
packages/gui/default.nix
```

Examples:

```nix
with pkgs; [
  localsend
  vscode
]
```

Add terminal applications here:

```text
packages/terminal/default.nix
```

Examples:

```nix
with pkgs; [
  bat
  btop
  git
  jq
  ripgrep
]
```

The aggregator files keep the install surfaces simple:

- `packages/system/default.nix` imports terminal and GUI packages for system-wide installation.
- `packages/user/default.nix` imports terminal packages for Home Manager user packages.

Put language toolchains and service-like developer dependencies in `developer/default.nix`
instead of `packages/terminal/default.nix`. For example: Docker, Node.js,
Python, Flutter, and Dart belong in `developer/`.

## GitLab CI/CD

The pipeline runs:

- `nix flake check`
- system derivation build
- optional Cachix push
- optional Attic push
- SBOM generation with `syft`
- GitLab Secret Detection
- manual laptop deployment through a tagged self-hosted runner

Required optional CI variables:

```text
CACHIX_AUTH_TOKEN
CACHIX_CACHE_NAME
ATTIC_ENDPOINT
ATTIC_CACHE
ATTIC_TOKEN
```

## Secrets

SOPS is wired but disabled for first install so `nixos-rebuild switch` does not
fail before `/var/lib/sops-nix/key.txt` exists.

Expected encrypted secret shape:

```yaml
tailscale_authkey: your-encrypted-tailscale-auth-key
grafana_secret_key: your-encrypted-grafana-secret-key
```

After the matching age private key is installed at `/var/lib/sops-nix/key.txt`,
enable the secrets path:

```nix
ivali.secrets.enable = true;
```

## Safety Notes

- VS Code settings are intentionally mutable. Do not add `programs.vscode.userSettings`.
- Node uses `tsx`; do not add the legacy `ts-node` package.
- Tailscale DNS and routes default to off to avoid broken internet during setup.
- Grafana, Prometheus, Loki, and Alloy are localhost-only unless you explicitly expose them.
- Generated hardware config belongs in `hosts/hardware-configuration.nix`.
