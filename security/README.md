# Security Architecture

This directory contains all NixOS security modules for the nixos-infrastructure repository.

## Module Overview

| Module | Purpose | Owner |
|--------|---------|-------|
| `audit.nix` | auditd rules for privilege escalation, identity changes, SSH config, kernel modules | `ivali.security.audit` |
| `apparmor.nix` | Mandatory Access Control profiles | `ivali.security.apparmor` |
| `firewall.nix` | nftables firewall, egress filtering, LocalSend LAN-only rules | `ivali.security.firewall` |
| `hardening.nix` | Kernel protection, PAM, coredump, Polkit hardening | `ivali.security.hardening` |
| `packages.nix` | Security utility packages | `ivali.security.packages` |
| `sudo.nix` | Sudo hardening and configuration | `ivali.security.sudo` |
| `tailscale.nix` | Tailscale VPN, exit node, metrics, key expiry monitoring | `ivali.tailscale` |
| `tailscale-acl.nix` | Declarative Tailscale ACL policy management | `ivali.tailscale` |
| `tailscale-policy.hujson` | Tailscale ACL policy (tag definitions, SSH rules, access rules) | — |
| `fail2ban.nix` | Brute-force protection | `ivali.security.fail2ban` |

## Port Inventory

| Port | Protocol | Direction | Interface | Service |
|------|----------|-----------|-----------|---------|
| 22/tcp | TCP | IN | tailscale0 only | SSH (filtered) |
| 80/tcp | TCP | IN | tailscale0 only | Grafana (Nginx reverse proxy) |
| 3478/udp | UDP | IN | All | STUN (Tailscale exit node) |
| 41641/udp | UDP | IN | All | Tailscale WireGuard |
| 53317/tcp | TCP | IN | LAN only (not tailscale0) | LocalSend file transfer |
| 53317/udp | UDP | IN | LAN only (not tailscale0) | LocalSend discovery |

## Audit Rules

The audit daemon (`auditd`) monitors:

- **Privilege escalation**: sudoers file changes, execve with euid=0 from non-root auid
- **Identity changes**: `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`
- **SSH configuration**: `/etc/ssh/` directory changes
- **Systemd configuration**: `/etc/systemd/` changes
- **GitOps state**: `/var/lib/gitops/` unexpected modifications
- **Cron**: crontab and cron.d changes
- **Failed access**: EACCES and EPERM on open() syscalls
- **Kernel modules**: init_module, finit_module, delete_module syscalls

### Audit Rules Rationale

On NixOS, binaries live in `/nix/store` and change on every rebuild. Traditional rules watching `/usr/bin/sudo` don't work. Instead, we use:
- File watches on mutable paths (`/etc/sudoers`, `/etc/ssh/`)
- Syscall-level auditing (`execve` with euid=0, `init_module`)
- auid-based rules that fire regardless of binary location

## Tailscale ACL Policy

The `tailscale-policy.hujson` file defines:

- **Tag definitions**: `tag:admin`, `tag:infra`, `tag:personal`, `tag:exit-node`, `tag:server`, `tag:laptop`
- **SSH rules**: Only `group:admin` can SSH to any node
- **Access rules**: Infra nodes can talk to each other; admins can SSH to infra; personal nodes can talk to each other

Apply via: `tailscale up --reset` (requires admin auth key)

## Firewall Architecture

- **Default policy**: Drop all inbound, allow all outbound
- **LocalSend**: TCP+UDP 53317 on LAN only (not tailscale0)
- **Egress filtering**: Optional default-deny outbound on non-Tailscale interfaces
- **Logging**: Disabled (incompatible with `security.lockKernelModules`)

## AppArmor Profiles

Profiles exist for: `sshd`, `gitops-reconciler`, `grafana-server`, `loki`, `prometheus`, `alertmanager`, `blocky`.

## Enabling Security Features

In your host configuration:

```nix
{
  ivali.security.audit.enable = true;
  ivali.security.firewall.enableEgressFiltering = true;
  ivali.tailscale.enablePolicy = true;
  ivali.tailscale.applyPolicy = true;  # Requires TAILSCALE_AUTH_KEY
}
```
