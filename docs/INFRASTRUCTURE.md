# Infrastructure Deep Dive

> Complete documentation of the NixOS infrastructure: flake, Home Manager, security stack, Tailscale mesh, Zero Trust networking, Blocky DNS filtering, self-healing, and system autonomy.

---

## Table of Contents

1. [The Flake](#1-the-flake) — Inputs, outputs, host configurations, what it does
2. [Home Manager](#2-home-manager) — User environment, module structure, configuration map
3. [Security Stack](#3-security-stack) — SOPS, hardening, AppArmor, Fail2Ban, scanning
4. [Tailscale & Zero Trust](#4-tailscale--zero-trust) — Zero trust model, daemon, exit node, metrics
5. [Blocky DNS Filtering](#5-blocky-dns-filtering) — Ad blocking, DoH/DoT, Tailscale integration
6. [Network-Level Filtering](#6-network-level-filtering) — nftables, egress filtering, layered defense
7. [The Tailnet](#7-the-tailnet) — MagicDNS, topology, how it ties into every system component
8. [Self-Healing](#8-self-healing) — 6 layers: systemd, health monitor, rollback, GitOps, Wi-Fi
9. [System Autonomy](#9-system-autonomy) — GitOps loop, boundaries, continuous operation

---

## 1. The Flake

### What Is a Flake?

A **Nix Flake** is a self-contained, hermetic package description format. It uses a `flake.nix` file to declare inputs (dependencies) and outputs (builds, configurations). Every input is pinned by content hash, meaning the same flake always produces the same result on any machine.

### This Repository's Flake (`flake.nix`)

The flake is the **entry point** for the entire system. It defines inputs and outputs that generate NixOS configurations for every host.

#### Inputs

```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
home-manager.url = "github:nix-community/home-manager";
sops-nix.url = "github:Mic92/sops-nix";
```

| Input | Purpose |
|-------|---------|
| `nixpkgs` | The NixOS package repository, tracking `unstable` |
| `home-manager` | User-level configuration manager (separate from NixOS) |
| `sops-nix` | Secret encryption/decryption using age |

The `inputs.nixpkgs.follows = "nixpkgs"` pattern on home-manager and sops-nix ensures they all use the **exact same** nixpkgs — no version conflicts.

#### How It Builds Host Configurations

The flake reads `hosts/hosts.nix`, which auto-discovers every `hosts/*.nix` file. Each host spec defines hostname, username, Tailscale tags, feature flags, and config overrides. The flake generates a `nixosConfigurations.<name>` for each host.

For each host, it assembles a **module list**:

1. `sops-nix.nixosModules.sops` — secret management
2. `home-manager.nixosModules.home-manager` — user environment
3. `./configuration.nix` — top-level module registry (auto-imports domains)
4. Host-specific hardware config (per-host or fallback)
5. `./lib/host-templates/laptop.nix` — NixOS host template
6. Go binary cache (for ivali and bw-tui)
7. Home Manager user config (imports `./home/ivali.nix`)

#### Outputs

| Output | Purpose |
|--------|---------|
| `packages.<system>.system` | System-wide package set (CLI + desktop) |
| `packages.<system>.user` | User-level package set |
| `packages.<system>.ivali` | ivali CLI (Go build) |
| `packages.<system>.bw-tui` | Bitwarden TUI (Go build) |
| `packages.<system>.default` | Default = prague's system build |
| `packages.<system>.hm-activate` | Standalone Home Manager activation |
| `nixosConfigurations` | One per host (prague, tuscany, testvm) |
| `checks.<system>.*` | 7 NixOS smoke tests |

#### What the Flake Does (Summary)

1. Accepts external dependencies with hermetic pinning
2. Reads host registry from `hosts/hosts.nix`
3. Generates NixOS configurations per host with all modules wired together
4. Builds Go tools (ivali CLI, bw-tui) with stable source hashing
5. Defines smoke tests validating security, observability, services, automation, Home Manager, bitwarden
6. Exposes a default package for `nix build` / `nix flake check`

---

## 2. Home Manager

### What Is Home Manager?

**Home Manager** is a Nix-based system for managing a user's environment. While NixOS manages system-level configuration (services, kernel, firewall), Home Manager manages user-level configuration (shell, dotfiles, packages, user services). They are complementary layers:

- **NixOS** = what the machine does (system services, networking, security)
- **Home Manager** = what the user sees and uses (shell, editors, aliases, themes)

### How It Is Wired Into the Flake

In `flake.nix`, Home Manager is included as a module in every host's NixOS configuration:

```nix
home-manager = {
  useGlobalPkgs = true;    # Use pkgs from NixOS system, not Home Manager fork
  useUserPackages = true;  # Install packages into user profile
  extraSpecialArgs = {
    inherit inputs hostSpec defaultUsername;
    hostName = hostSpec.hostName;
    username = hostSpec.userName or defaultUsername;
  };
  users.${hostSpec.userName or defaultUsername} = import ./home/ivali.nix;
  backupFileExtension = "hm-backup";
};
```

Key points:
- **useGlobalPkgs = true**: Home Manager can use NixOS packages (no duplication)
- **useUserPackages = true**: Packages install to `~/.nix-profile` instead of system-wide
- **backupFileExtension**: When Home Manager writes a file that exists, it creates a `.hm-backup` instead of overwriting

### Home Manager Module Structure

Entry point is `home/ivali.nix`, which imports `home/default.nix`. The default.nix conditionally includes modules:

```nix
imports = [
  ./identity     # User identity (username, homeDirectory, stateVersion)
  ./fonts.nix    # Nerd Fonts, MS Office fonts, Noto
  ./theming.nix  # GTK theme
  ./firefox      # Firefox config
] ++ (if gnomeEnabled then [ ./gnome ./launcher ./audio ./webapps ./cloud ] else [ ]) ++ [
  ./shell        # Shell environment (Zsh, aliases, tools, integrations)
  ./git          # Git config, delta, git-lfs
  ./environment  # Session variables, XDG paths, locale
  ./editors      # Zed editor
  ./services     # User services (auto-format)
];
```

### What Home Manager Configures

| Module | What It Does |
|--------|-------------|
| `identity/` | Username, home directory, Home Manager enable flag |
| `shell/` | Zsh, Powerlevel10k, FZF, zoxide, direnv, Atuin, aliases (git/nix/nav/util/dev/ivali), startup scripts (dashboard, keybindings, completion, options), tools (bat, btop, eza, fastfetch), Bitwarden CLI integration |
| `git/` | Git config, delta diff viewer (gruvbox), git-lfs, gitui, lazygit |
| `gnome/` | GNOME Shell settings (Gruvbox), extensions (tiling, dash), dconf, MIME handlers, applications |
| `firefox/` | Firefox (privacy, performance, Sidebery, Gruvbox theme) |
| `editors/` | Zed editor with Nix/Python/Go/TS extensions |
| `environment/` | Session variables, XDG paths, MIME types, locale, packages |
| `fonts.nix` | Nerd Fonts (FiraCode, JetBrainsMono), MS Office fonts, Noto |
| `theming.nix` | GTK theme (Gruvbox) |
| `services/` | Auto-format .nix files on change (watchexec + nix fmt) |
| `cloud/` | OneDrive integration |
| `launcher/` | Desktop launcher config |
| `audio/` | Audio configuration |
| `webapps/` | Edge PWA web apps |

### Home Manager State Version

`home.stateVersion = "26.11"` — pins the Home Manager release. Changing this major version can break configurations, so it should only be updated intentionally.

---

## 3. Security Stack

The security stack is composed of **8 independent modules**, each owning a specific security domain. No module depends on another's internal state — they communicate through NixOS options only.

### 3.1 SOPS Secrets (`security/sops.nix`)

**Purpose**: Secret management using age encryption.

**How it works**:
- Files in `secrets/*.yaml` are encrypted with age (via `.sops.yaml` config)
- sops-nix decrypts them at build time and places them in `/run/secrets/`
- SOPS key is loaded from `/home/ivali/.config/sops/age/keys.txt`
- Decryption fails closed — features requiring secrets won't activate until the age key is installed
- Includes key rotation script (`sops-rotate`) with backup and re-encryption guidance

**Secrets managed**:
| File | Contents |
|------|----------|
| `tailscale.yaml` | Tailscale auth key, Grafana secret |
| `notifications.yaml` | Email notification recipients |
| `smtp.yaml` | SMTP credentials (Office365 OAuth2) |
| `gitlab-runner.yaml` | Runner registration token |
| `gitlab.yaml` | GitLab API token |
| `bitwarden.yaml` | Bitwarden secrets |
| `hosts/<name>.yaml` | Per-host secrets |

**Rotation**: 90-day max age. Secrets older than this are flagged by `ivali doctor`.

### 3.2 Kernel Hardening (`security/hardening.nix`)

**Purpose**: Kernel protection, PAM, audit, coredump, and Polkit hardening.

| Setting | Value | Effect |
|---------|-------|--------|
| `security.protectKernelImage` | true | Prevents modifying kernel image |
| `security.lockKernelModules` | true | Prevents loading/unloading kernel modules |
| `security.rtkit.enable` | true | Real-time policy kit for latency-sensitive tasks |
| `security.polkit.enable` | true | PolicyKit for privilege escalation |
| `security.pam.loginLimits` | maxlogins=10, core=0 | Limit logins, disable core dumps |
| `systemd.coredump.enable` | false | Disable core dumps |
| `security.audit.enable` | false | Audit framework (disabled) |
| `security.auditd.enable` | false | Audit daemon (disabled) |

### 3.3 Sudo Hardening (`security/sudo.nix`)

| Setting | Value | Effect |
|---------|-------|--------|
| `security.sudo.enable` | true | Enable sudo |
| `security.sudo.execWheelOnly` | true | Only wheel group can sudo |
| `timestamp_timeout` | 5min | Sudo cache duration |
| `passwd_tries` | 3 | Max password attempts |
| `use_pty` | true | Require PTY for sudo |
| `logfile` | `/var/log/sudo.log` | Log all sudo commands |

### 3.4 AppArmor (`security/apparmor.nix`)

**Purpose**: Mandatory access control with custom profiles for infrastructure components.

**Three custom profiles** (all enforced):

| Profile | Attached To | Scope |
|---------|-------------|-------|
| `blocky` | Blocky DNS service | Read-only Nix store, state dirs, network, deny /home /root /etc/shadow |
| `ivali-api` | Operations Web UI | Repo + deployment state, proc/sys read-only, deny secrets |
| `ivali-cli` | On-demand (per-service) | Repo read-only, devices, proc/sys read-only, deny secrets |

**Important notes**:
- DevOps tools (kubectl, helm, terraform) are NOT confined — they need broad access
- The gitops-reconciler runs UNCONFINED (bash shared-lib loading broke under AppArmor)
- `ivali-cli` is NOT attached to a path glob — enforced only when a service explicitly sets `AppArmorProfile = "ivali-cli"` (prevents breaking every `ivali` invocation system-wide)

### 3.5 Fail2Ban (`security/fail2ban.nix`)

**Purpose**: Brute-force protection for SSH and nginx.

| Jail | Max Retry | Find Time | Ban Time |
|------|-----------|-----------|----------|
| SSHD | 3 | 10min | 1h (with increment up to 168h) |
| nginx-http-auth | 5 | 10min | 1h |
| nginx-bad-request | 10 | 10min | 1h |
| nginx-botsearch | 5 | 10min | 24h |

**Bantime increment**: exponentially increases ban time (2x, 4x, 8x...) up to 168h for repeated offenders.

### 3.6 Security Scanning (`security/scanning.nix`)

**Purpose**: Daily automated security audit with Prometheus metrics.

**What it scans**:
1. NixOS configuration integrity (flake inputs)
2. Store integrity (size, derivation count)
3. Critical service status (tailscaled, sops-nix, nixos-rebuild-switch)
4. Failed systemd units
5. Open ports
6. Kernel version and generation
7. AppArmor status
8. Fail2Ban status
9. Tailscale status

**How it works**: A shell script runs daily via systemd timer, outputs Prometheus metrics to `/var/lib/security-scanner/`, served by a Python HTTP server on `127.0.0.1:9120`. Prometheus scrapes it locally.

### 3.7 Summary

| Layer | Technology | What It Protects |
|-------|-----------|-----------------|
| Kernel | slab_nomerge, pti=on, vsyscall=none, randomize_kstack_offset | Kernel exploit mitigation |
| Sysctl | kptr_restrict=2, dmesg_restrict=1, unprivileged_bpf_disabled=1, perf_event_paranoid=3 | Information disclosure |
| Lockdown | protectKernelImage, lockKernelModules | Kernel modification |
| Access Control | AppArmor (3 profiles), Polkit | Process and privilege escalation |
| Network | nftables default-deny, Tailscale-only SSH | Network access |
| Brute-Force | Fail2Ban (SSH + nginx) | Credential attacks |
| Secrets | SOPS + age encryption | Secret at-rest and in-build |
| Monitoring | Daily security scanner | Configuration drift |
| SSH | Password disabled, root disabled, X11 off, key-only | Remote access |

---

## 4. Tailscale & Zero Trust

### What Is Zero Trust?

Zero Trust is a security model where no user, device, or network traffic is trusted by default — even inside the network. Every connection must be verified. Tailscale implements this by:

1. **All traffic is encrypted** (WireGuard) regardless of network location
2. **Authentication is identity-based** (Tailscale accounts, not IP addresses)
3. **Access is policy-driven** (ACL tags control who can reach what)
4. **There is no "inside" vs "outside"** — every connection is treated as originating from the untrusted internet

### How Tailscale Works in This System

The `security/tailscale.nix` module configures the Tailscale daemon:

| Option | Default | Purpose |
|--------|---------|---------|
| `enable` | true | Enable Tailscale daemon |
| `authKeyFile` | null | SOPS-provided reusable auth key |
| `tags` | `["tag:admin"]` | ACL tags for access control |
| `acceptDns` | true | MagicDNS split-DNS via systemd-resolved |
| `magicDnsCheck` | false | Periodic MagicDNS health check (disabled by default) |
| `metricsExportInterval` | 60s | Prometheus metrics collection frequency |
| `acceptRoutes` | false | Accept routes from other nodes |
| `advertiseExitNode` | true | Advertise as exit node for full-tunnel VPN |
| `enableTailscaleSsh` | false | Tailscale's built-in SSH server |
| `tailnetDomain` | null | MagicDNS domain (e.g., `codlet-trench.ts.net`) |
| `keyExpiryWarningDays` | 14 | Warning threshold for key expiry |

**Tag validation at build time**: Tags must start with `tag:` and contain only alphanumeric characters, hyphens, and underscores. Invalid tags cause a build error — no accidental misconfigurations.

When `advertiseExitNode = true`, `tag:exit-node` is automatically appended to the tag list, and the kernel flags `net.ipv4.ip_forward = 1` and `net.ipv6.conf.all.forwarding = 1` are set.

### Tailscale Components

**tailscaled Service**: Runs continuously with `Restart = "always"`, `RestartSec = "5s"`. Waits for `network-online.target`. No privilege limit on start attempts (`StartLimitIntervalSec = 0`).

**Key Expiry Monitoring**: `tailscale-key-check` service runs **daily** via systemd timer. Checks `tailscale status --json` for key expiry date. Exits 0 (warning) if <14 days, exits 1 (critical) if expired.

**Prometheus Metrics**: `tailscale-metrics` service runs every 60 seconds. Collects: connection status, key expiry days, MagicDNS status, exit node status, peer counts, throughput. Serves metrics on `127.0.0.1:9121` via socat (loopback only). Prometheus scrapes locally.

**MagicDNS**: Handled entirely by Tailscale itself — `acceptDns = true` registers `100.100.100.100` with systemd-resolved for the tailnet domain. No custom split-DNS service (a previous implementation was removed because it fought Tailscale).

### Exit Node

When `advertiseExitNode = true`:
- Tailscale advertises this machine as an exit node to the coordination server
- Other tailnet members can route ALL their traffic through this machine
- Kernel IP forwarding is enabled (IPv4 and IPv6)
- nftables firewall opens STUN port (3478) for exit node NAT traversal
- Exit node status is verified at runtime via `tailscale debug prefs` (checking advertised routes)
- A separate metric `tailscale_exit_node_configured` reflects the declarative intent from Nix config

### Security Model

1. **SSH**: Password authentication disabled system-wide. Only Tailscale-tunneled connections or key-based SSH allowed
2. **Firewall**: Only WireGuard (41641 UDP), STUN (3478 UDP for exit nodes), and LocalSend (53317 TCP/UDP) ports open inbound
3. **No open ports**: All observability services (Grafana, Prometheus, Loki) bind to localhost only, accessible via Tailscale Serve or SSH tunnel
4. **Tailscale-only SSH** (optional): When `enableTailscaleSsh = true`, Tailscale intercepts all port-22 traffic from the tailnet, authenticating via ACL rules — bypassing sshd entirely

---

## 5. Blocky DNS Filtering

### What Is Blocky?

**Blocky** is a privacy-focused DNS proxy and ad/tracker/malware blocker. It sits between the system's DNS resolver and upstream DNS servers, blocking requests to known advertising, tracking, and malware domains.

### How Blocky Works

The `services/blocky/config.nix` module configures Blocky:

| Option | Default | Purpose |
|--------|---------|---------|
| `enable` | true | Enable Blocky |
| `port` | 53 | DNS port (UDP/TCP) |
| `metricsPort` | 4000 | Prometheus metrics HTTP port |
| `upstreams` | `["1.1.1.1", "9.9.9.9"]` | Upstream DNS resolvers (supports plain DNS, DoH, DoT) |
| `blocklists` | StevenBlack hosts + fakenews-gambling-porn | URLs to download blocklists at startup |
| `tailscaleOnly` | true | Restrict DNS port to tailscale0 interface only |

**Blocking logic**:
1. At startup, Blocky downloads blocklists from configured URLs into memory
2. When a DNS query arrives, Blocky checks the domain against blocklists
3. If matched, the query is blocked (returns NXDOMAIN)
4. If not matched, the query is forwarded to upstream resolvers
5. Prometheus metrics are exposed on port 4000

### Blocky + Tailscale Integration

Blocky's DNS port (53) is opened **only on the tailscale0 interface** when `tailscaleOnly = true`. This means:
- Other tailnet members can use this machine's Blocky for DNS filtering
- The public internet cannot reach Blocky
- DNS queries over the tailnet are filtered

### Blocky + AppArmor

Blocky runs confined by the `blocky` AppArmor profile which restricts:
- Read-only access to /nix/store (with mmap for shared libs)
- Read/write to /var/lib/blocky and /run/blocky
- Network access (TCP/UDP IPv4 and IPv6)
- Deny: /root, /home, /etc/shadow

### Prometheus Scrape Registration

The Blocky Prometheus scrape target is registered by `observability/prometheus.nix` (single authoritative owner), not by the Blocky module itself. This follows the principle of single ownership.

---

## 6. Network-Level Filtering

### Architecture

Network filtering is implemented at two layers:

1. **nftables** (via NixOS `networking.nftables`) — packet-level firewall rules
2. **Tailscale ACLs** — identity-based access control for the tailnet

### nftables Firewall (`security/firewall.nix`)

**Default policy**:
- Inbound: default deny (NixOS networking.firewall default-deny)
- Outbound: allow by default (egress filtering is opt-in)

**Inbound rules**:
| Port | Protocol | Purpose |
|------|----------|---------|
| 41641 | UDP | Tailscale WireGuard |
| 3478 | UDP | STUN (exit nodes only) |
| 53317 | TCP/UDP | LocalSend |

**Key settings**:
- `allowPing = false` — ping blocked
- `checkReversePath = "loose"` — required for Tailscale exit nodes
- `trustedInterfaces = []` — no trusted interfaces by default
- `logRefusedConnections = false` — disabled (conflicts with kernel module locking)

### Egress Filtering (Opt-In)

When `enableEgressFiltering = true` (disabled by default), a default-deny outbound policy is installed on non-Tailscale interfaces.

**Static baseline** (build-time, always allowed — no DNS needed):
- DNS resolvers: 1.1.1.1, 1.0.0.1, 9.9.9.9, 9.9.10.10, 8.8.8.8 (IPv4 + IPv6)

**Runtime-resolved domains** (resolved at boot by `ivali-egress-refresh` service):
- NixOS update servers: nixos.org, cache.nixos.org, flakes.nixos.org
- Git: gitlab.com, github.com
- Time: time.nixos.org, time.cloudflare.com
- Plus any user-configured `allowedEgressDomains`

**How runtime resolution works**:
1. `ivali-egress-refresh` service runs every 5 minutes
2. Resolves all allowed domains to IPs using `dig`
3. Writes IPs to nftables runtime sets (`allowed_runtime_v4`, `allowed_runtime_v6`)
4. Static baseline is preserved; runtime set is flushed and rebuilt (idempotent)
5. The nftables ruleset includes both static and runtime sets in the allow rules

**Exit node preservation**: When advertising an exit node, the forward chain is left unrestricted (the NixOS `checkReversePath` handles this). Egress filtering must never break the zero-trust overlay, exit-node forwarding, or MagicDNS.

### The Principle: Layered Defense

```
Packet arrives
   │
   ├── Is it from Tailscale (100.64.0.0/10)?
   │   ├── YES: Pass through (trust zone, filtered by ACLs)
   │   └── NO: Check nftables rules
   │       ├── Is it loopback/link-local? → Allow
   │       ├── Is it in egress allow-list? → Allow
   │       └── Otherwise → Drop
   │
   └── Is it SSH?
       ├── From tailscale0? → Check sshd config (Tailscale-only)
       └── Otherwise → Drop (firewall blocks)
```

---

## 7. The Tailnet

### What Is the Tailnet?

The **tailnet** is the Tailscale virtual network — a WireGuard-based overlay network that connects all trusted devices. In this infrastructure, the tailnet serves as the primary communication fabric.

### Tailnet Configuration

From `hosts/prague.nix`:

```nix
tailnetDomain = "codlet-trench.ts.net";
features = {
  secrets = true;
  gitlabRunner = true;
  tailscale = true;
  tailscaleExitNode = true;
  ssh = true;
};
```

The `tailnetDomain` enables MagicDNS split-DNS. All hosts in the tailnet can reach each other via `<hostname>.<tailnetDomain>` names (e.g., `prague.codlet-trench.ts.net`).

### How the Tailnet Ties Into the System

The tailnet is the **central communication backbone** for every aspect of this infrastructure:

1. **SSH Access**: All SSH is Tailscale-only (port 22 closed on public interfaces). When `enableTailscaleSsh = false`, sshd still runs but only accepts key-based connections from the Tailscale interface (`tailscale0`). This means you can only SSH into the machine from another device on the tailnet.

2. **Control Plane Exposure**: All web services are exposed via Tailscale Serve on port 443:
   ```
   Tailscale MagicDNS → prague.codlet-trench.ts.net
       │
       ▼
   Tailscale Serve (HTTPS termination, port 443)
       ├── /grafana/     → Grafana (port 3000)
       ├── /prometheus/  → Prometheus (port 9090)
       ├── /loki/        → Loki (port 3100)
       ├── /health       → Health endpoint (port 9100)
       └── /             → Operations Web UI (port 8080)
   ```

3. **GitOps Communication**: The gitops-reconciler fetches from and pushes to `git@gitlab.com:willisivali/nixos-infrastructure.git` using a passphrase-less SSH deploy key. While GitLab is on the public internet, all other infrastructure services communicate exclusively over the tailnet.

4. **DNS Filtering**: Blocky provides DNS filtering on the tailnet (port 53 on tailscale0). Other tailnet members can use this machine's Blocky for filtered DNS resolution.

5. **Exit Node Routing**: This machine advertises as an exit node (`advertiseExitNode = true`), meaning other tailnet members can route ALL their traffic through it. This provides:
   - Internet access from any tailnet member via this machine's IP
   - The ability to access the internet only from tailnet members
   - Monitoring of exit node traffic via Prometheus metrics

6. **Secret Distribution**: SOPS-encrypted secrets are stored in the Git repository. SOPS decryption requires the age private key, which exists only on tailnet members that need it. The tailnet ensures only authorized devices can participate in the GitOps loop.

7. **Notification Delivery**: Email notifications go through Office365 SMTP (public internet), but Telegram bot notifications are delivered over the tailnet.

8. **Observability Scraping**: Prometheus on this machine scrapes all local services. Remote machines in the tailnet can scrape metrics via Tailscale Serve if configured.

### Tailnet Topology

```
┌──────────────────────────────────────────────────────┐
│                   Tailscale Cloud                     │
│            (Coordination + DERP relay)               │
└──────────┬───────────────────────────────┬───────────┘
           │                               │
    ┌──────┴──────┐                ┌──────┴──────┐
    │   prague    │◀──────────────▶│  other      │
    │ (exit node) │                │  tailnet    │
    │             │                │  members    │
    │ • Grafana   │                │ • laptops   │
    │ • Prometheus│                │ • servers   │
    │ • Blocky    │                │ • mobile    │
    │ • Blocky    │                │ • CI bots   │
    │   DNS (53)  │                │             │
    │ • Ivali API │                │             │
    │ • Nginx     │                │             │
    │ • SSH       │                │             │
    └─────────────┘                └─────────────┘
```

### MagicDNS

With `acceptDns = true` and `tailnetDomain = "codlet-trench.ts.net"`:
- Every host in the tailnet can be reached via `<hostname>.codlet-trench.ts.net`
- systemd-resolved is configured to use Tailscale's resolver (100.100.100.100) for the tailnet domain only
- Global DNS is not overridden — only tailnet names use MagicDNS

### Key Management

- **Expiry**: Keys expire after a configurable period (default 90 days in Tailscale admin console)
- **Monitoring**: `tailscale-key-check` service runs daily, warning at 14 days, critical at expiry
- **Prometheus metrics**: `tailscale_key_expiry_days` metric tracks time-to-expiry
- **Alerting**: Prometheus alerting rules fire on key expiry warnings

---

## 8. Self-Healing

### What Is Self-Healing?

Self-healing is the system's ability to automatically detect problems and recover without human intervention. This infrastructure implements self-healing at three levels:

1. **Service-level**: Individual services restart automatically (systemd `Restart = "always"`)
2. **Health-level**: Periodic health checks detect drift and trigger remediation
3. **System-level**: Failed deployments are automatically rolled back

### The Self-Healing Stack

#### Layer 1: Systemd Service Resilience

Many critical services are configured to restart automatically:

| Service | Restart Policy |
|---------|---------------|
| `tailscaled` | `always`, 5s delay |
| `tailscale-metrics` | `on-failure`, 10s delay |
| `nix-repo-auto-format` | `on-failure`, 5s delay |

#### Layer 2: Deployment Health Monitor (`recovery/deployment-health.nix`)

**Purpose**: Validates that the node is healthy for GitOps operations every 5 minutes.

**What it checks** (9 categories):
1. **System**: systemd running, network-online active
2. **Network**: ping reachable, DNS resolving
3. **GitLab**: HTTP check
4. **GitOps repo**: Remote reachable, branch exists
5. **Local worktree**: Directory exists, flake present, git status clean, flake evaluates
6. **Baseline**: Tailscale active, NTP synchronized
7. **Critical services**: sshd, NetworkManager, tailscaled, blocky, nftables running
8. **Disk**: Usage <90% critical, <80% warning
9. **Generations**: At least 2 (rollback available)

**How it works**:
- Runs as a systemd service via a timer (`*:0/5` — every 5 minutes)
- Runs in hardened mode (NoNewPrivileges, PrivateTmp, ProtectSystem=strict, etc.)
- Writes results to `/var/lib/deployment-health/last-results.json`
- Can run in two modes:
  - **Strict mode** (default for GitOps): Connectivity failures fail the check
  - **Observer mode** (for retry): Connectivity failures only warn, genuine service failures still fail

#### Layer 3: Rollback on Failure (`recovery/rollback.nix`)

**Purpose**: Automatically rolls back to the previous NixOS generation when health checks fail after a deployment.

**How it works**:
1. When `deployment-health` service fails, `rollback-on-failure.service` is triggered (via `onFailure`)
2. The rollback script sleeps 30s for services to settle
3. Guards against concurrent rollbacks (flock on `/run/rollback.lock`)
4. Guards against rollback during active `nixos-rebuild` (pgrep check)
5. Re-runs health check in **observer mode** (STRICT_HEALTH=false): connectivity blips do NOT trigger rollback; genuine service regressions still do
6. If health check still fails, runs `rollback.sh`
7. `rollback.sh` is the **single rollback authority** — all other rollback paths delegate to it

#### Layer 4: The Rollback Script (`scripts/rollback.sh`)

This script is the **single source of truth** for rollbacks. Every rollback path (gitops-reconcile.sh, rollback-on-failure.service, manual operator invocation) delegates to this script.

**Key features**:
1. **Concurrency control**: Uses flock on `/run/rollback.lock` — prevents two rollback paths from racing
2. **Hysteresis (cooldown)**: 15-minute cooldown between rollbacks prevents the tight loop: rollback → fail → rollback → fail
3. **Generation tracking**: Uses `readlink` on the system profile symlink (world-readable) rather than `nix-env` (needs root lock)
4. **Post-rollback health gate**: After rollback, verifies health before declaring success
5. **Notification**: Sends email on success and failure

#### Layer 5: GitOps Self-Healing (`scripts/gitops-reconcile.sh`)

The GitOps reconciler is the primary self-healing mechanism at the system level. It runs every 15 minutes and handles the full deployment lifecycle:

```
timer (every 15min)
  └── gitops-reconciler.service
       └── gitops-reconcile.sh
            ├── flock (mutual exclusion via /run/deploy.lock)
            ├── stale lock detection (30min max age)
            ├── repo provisioning (clone if missing)
            ├── dirty-tree guard (skip if uncommitted changes)
            ├── git fetch (with retry + exponential backoff)
            ├── git fsck (corruption recovery — re-clone if corrupted)
            ├── git pull --ff-only (with retry)
            ├── nix flake check
            ├── hardware UUID validation
            ├── Go vendor hash verification
            ├── nix build .#nixosConfigurations.<host>.config.system.build.toplevel
            ├── canary VM test (optional, GITOPS_CANARY=1)
            ├── nixos-rebuild switch
            ├── 30s grace period
            ├── health check (deployment-health.sh → ivali doctor)
            ├── on failure → rollback.sh → nixos-rebuild switch --rollback
            └── email notification (generation diff, commit, duration)
```

**Key resilience features**:
- **Fetch retry**: Up to 3 retries with exponential backoff (5s, 10s, 20s)
- **Network failure handling**: If fetch fails, the system keeps current config and exits cleanly (system is healthy, just unreachable)
- **Corruption recovery**: If `git fsck` fails, automatically re-clones the repository
- **Dirty-tree guard**: Prevents deploying uncommitted changes (4 checks: modified, staged, untracked, detached HEAD)
- **Stale lock detection**: If lock file is >30min old, assumes crash and removes it
- **Rollback on failure**: Automatic rollback with hysteresis

#### Layer 6: Wi-Fi Self-Healing (`networking/networkmanager.nix`)

NetworkManager has a self-healing feature that purges stale Wi-Fi profiles:
- Runs every 10 minutes via systemd timer
- Checks which SSIDs are currently visible
- Removes NetworkManager profiles whose SSID is no longer in range
- Prevents the system from being "locked" to old networks

### The Self-Healing Flow

```
Normal operation
       │
       ▼
Deployment (git push → reconciler)
       │
       ▼
Health check passes → Done (new generation active)
       │
       ▼
Health check FAILS
       │
       ▼
rollback-on-failure triggered
       │
       ▼
Wait 30s → Re-check (observer mode)
       │
       ├── Still failing → rollback.sh → nixos-rebuild --rollback
       │                        │
       │                        ├── Health OK → Notify success
       │                        └── Health still failing → Notify escalation
       │
       └── Connectivity blip → No rollback (hysteresis)
```

---

## 9. System Autonomy

### What Is System Autonomy?

System autonomy means the machine operates and maintains itself with minimal human intervention. This infrastructure achieves autonomy through:

1. **GitOps reconciliation** — the system pulls its own updates
2. **Health monitoring** — the system watches itself
3. **Self-healing** — the system fixes itself
4. **Declarative configuration** — the system knows what it should look like
5. **Notification** — the system alerts humans only when it cannot fix itself

### The Autonomy Architecture

```
┌──────────────────────────────────────────────────────┐
│                   Autonomy Loop                        │
│                                                       │
│   ┌─────────┐    ┌─────────┐    ┌──────────┐        │
│   │  Git    │───▶│ Deploy  │───▶│  Health  │        │
│   │  Push   │    │ Apply   │    │  Check   │        │
│   └─────────┘    └─────────┘    └────┬─────┘        │
│        ▲                              │               │
│        │         ┌──────────┐        │               │
│        │         │  Rollback │◀───────┘               │
│        │         │  (if fail)│                        │
│        │         └──────────┘                        │
│        │                                            │
│        └────── Timer (every 15 min)                  │
│                                                       │
│   All automated. Human involvement only for:         │
│   - Initial setup                                   │
│   - Major changes reviewed via MR                    │
│   - Failures requiring manual diagnosis              │
└──────────────────────────────────────────────────────┘
```

### How Each Component Contributes to Autonomy

#### GitOps Reconciler — The Brain
- Runs every 15 minutes (configurable)
- Pulls changes from GitLab (the source of truth)
- Builds and activates new configurations
- Never requires manual intervention for routine updates
- On failure, self-repairs via rollback
- Sends notifications on every action (success, failure, skip)

#### Health Monitor — The Sentinel
- Checks 11 health dimensions every 5 minutes
- Distinguishes between transient failures (network blips) and genuine problems (service crashes)
- Generates structured JSON results for programmatic consumption
- Writes history files for trend analysis
- Feeds the rollback decision

#### Rollback System — The Safety Net
- Hysteresis prevents thrashing (15-minute cooldown)
- Observer mode prevents false rollbacks
- Single authoritative script (`rollback.sh`) prevents concurrent rollbacks
- Post-rollback verification ensures the fix worked

#### Notification System — The Reporter
- Email via Office365 SMTP (OAuth2)
- Telegram (via Alertmanager)
- Desktop notifications (GNOME notify-send)
- Only alerts humans when automated systems reach their limits

#### Declarative Configuration — The Blueprint
- Every aspect of the system is described in Nix expressions
- The system can always compare its actual state to the desired state
- Drift detection is possible because the desired state is version-controlled
- `ivali status` shows current repository state vs Git state

### The Autonomy Boundaries

What the system does **automatically**:
- Pull and apply configuration changes
- Run health checks
- Rollback on failure
- Send notifications
- Rotate logs
- Format Nix files on change
- Prune stale Wi-Fi profiles
- Check Tailscale key expiry
- Run security scans
- Rebuild Nix store garbage collection

What requires **human decision**:
- Initial system installation
- Reviewing and merging configuration changes
- Diagnosing and fixing complex failures
- Rotating SOPS keys
- Adding new hosts
- Changing security policies

### Monitoring the Autonomy

The `ivali` CLI provides observability into the autonomous system:

| Command | Purpose |
|---------|---------|
| `ivali status` | Repository state, health |
| `ivali doctor` | Full health check |
| `ivali dashboard` | Interactive TUI (6 tabs) |
| `ivali reconcile` | Force GitOps reconciliation |
| `ivali health` | System health |
| `ivali metrics` | Repository metrics |
| `ivali api` | REST API for control plane |

### Continuous Operation

The system is designed for **continuous operation** without reboots:
- NixOS generation switching allows updates without reboot
- Services restart automatically on failure
- The GitOps loop keeps the system in sync with the repository
- Rollback ensures problems are recoverable
- Health monitoring catches issues before they become critical

The only planned downtime is for kernel updates or major configuration changes that require a reboot (noted in `nixos-rebuild boot` vs `nixos-rebuild switch`).

---


