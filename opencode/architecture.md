# Architecture

## System Overview

This is a **single-user NixOS infrastructure** designed for autonomous operation.
The system is declarative, self-healing, and remotely controllable via Telegram.

```
┌─────────────────────────────────────────────────────┐
│                    User (ivali)                      │
│              Telegram Bot / SSH / GNOME              │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                 NixOS System                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ Home     │  │ Desktop  │  │ Developer        │  │
│  │ Manager  │  │ GNOME    │  │ Go/Node/Python   │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ Security │  │ Boot     │  │ Networking       │  │
│  │ SOPS/age │  │ systemd  │  │ NetworkManager   │  │
│  │ Tailscale│  │ boot     │  │ DNS              │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │           Observability Stack                 │  │
│  │  Prometheus → Grafana ← Loki ← Alloy         │  │
│  │                   ↑                           │  │
│  │               Falco (runtime security)        │  │
│  └──────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │           Recovery & Self-Heal                 │  │
│  │  deployment-health → gitops-reconciler         │  │
│  │  self-heal → rollback                         │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Core Principles

1. **Declarative** — Every configuration is a Nix expression. No imperative state.
2. **Self-Healing** — Health checks detect drift and trigger reconciliation.
3. **GitOps** — Git is the source of truth. Push to deploy.
4. **Zero-Touch** — Automatic updates, health monitoring, rollback on failure.
5. **Remote Control** — Telegram bot provides full system control from any device.

## Module System

### Auto-Import

`configuration.nix` uses `lib/auto-imports.nix` to discover and import all
NixOS domain modules automatically. Any directory with a `default.nix` at
the repo root is treated as a domain module.

```
configuration.nix
  ├── auto-imports.nix reads repo root
  ├── imports: boot/, networking/, security/, desktop/, ...
  ├── imports: [ ./desktop, ./packages/system ]  (explicit)
  └── auto-discovers: all other dirs with default.nix
```

### Host Registry

`hosts/hosts.nix` is an auto-aggregator that discovers per-host spec files
from `hosts/*.nix` and builds the registry attrset:

```nix
{
  prague = {
    hostName = "prague";
    userName = "ivali";
    repoPath = "/home/ivali/nixos-infrastructure";
    tags = [ "tag:admin" ];
    tailnetDomain = "codlet-trench.ts.net";
    features = { secrets = true; gitlabRunner = true; ... };
    config = { ... };  # extra overrides
  };
}
```

### Template System

`lib/host-templates/laptop.nix` is a NixOS module that reads `hostSpec`
from `specialArgs` and generates the full configuration:
- Host identity (networking.hostName)
- User account
- Sudo rules
- Git system config
- SOPS secrets definitions
- GitLab Runner
- Telegram bot
- Tailscale networking
- SSH daemon

## Data Flow

### Deployment Flow
```
git push (GitLab, source of truth) → GitHub mirror → GitHub Actions validate
  → posts status to GitLab → GitOps reconciler: pull → flake check → build
  → nixos-rebuild switch → health check
```

### Self-Heal Flow
```
deployment-health timer (5min) → detect failure → gitops-reconciler
```

### Rollback Flow
```
health check fail → rollback to previous generation → notify via Telegram
```

### Reconciliation Flow
```
gitops-reconcile timer (15min) → git pull → nix flake check → rebuild → health
```

## Security Model

- **Secrets**: SOPS with age encryption, decrypted at runtime to `/run/secrets/`
- **Network**: Tailscale-only SSH, nftables firewall (default deny)
- **Kernel**: Hardened (slab_nomerge, init_on_alloc, pti=on, etc.)
- **Runtime**: Falco detects suspicious system calls
- **Access**: SSH key-only auth, no password login
