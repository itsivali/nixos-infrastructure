# Ivali Infrastructure Deep Dive

> Comprehensive technical documentation of the Ivali infrastructure platform: NixOS, Nix Flakes, Home Manager, KDE Plasma, Linux, security, Tailscale Zero Trust networking, DNS filtering, GitOps, observability, self-healing, disaster recovery, SRE practices, and autonomous operations.

---

## Table of Contents

1. [Infrastructure Philosophy](#1-infrastructure-philosophy)
2. [Infrastructure Architecture](#2-infrastructure-architecture)
3. [The Nix Flake](#3-the-nix-flake)
4. [NixOS Host Architecture](#4-nixos-host-architecture)
5. [Home Manager](#5-home-manager)
6. [KDE Plasma Desktop](#6-kde-plasma-desktop)
7. [Linux Platform](#7-linux-platform)
8. [Security Architecture](#8-security-architecture)
9. [SOPS and Secret Management](#9-sops-and-secret-management)
10. [Tailscale and Zero Trust](#10-tailscale-and-zero-trust)
11. [Network Security and nftables](#11-network-security-and-nftables)
12. [Blocky DNS](#12-blocky-dns)
13. [Observability](#13-observability)
14. [GitOps and Continuous Reconciliation](#14-gitops-and-continuous-reconciliation)
15. [Self-Healing and Recovery](#15-self-healing-and-recovery)
16. [Backup and Disaster Recovery](#16-backup-and-disaster-recovery)
17. [SRE Operating Model](#17-sre-operating-model)
18. [TDD and Verification](#18-tdd-and-verification)
19. [Architecture Governance](#19-architecture-governance)
20. [The Tailnet](#20-the-tailnet)
21. [Oracle Edge Architecture](#21-oracle-edge-architecture)
22. [System Autonomy](#22-system-autonomy)
23. [Operational Interfaces](#23-operational-interfaces)
24. [Failure and Recovery Model](#24-failure-and-recovery-model)
25. [Infrastructure Lifecycle](#25-infrastructure-lifecycle)
26. [Definition of Done](#26-definition-of-done)

---

# 1. Infrastructure Philosophy

The Ivali infrastructure is designed around one central principle:

> **The infrastructure should be reproducible, observable, secure, recoverable, testable, and capable of operating continuously with minimal manual intervention.**

This is not simply a collection of NixOS configuration files.

It is an **infrastructure platform**.

The platform combines:

* NixOS
* Nix Flakes
* Home Manager
* KDE Plasma
* Linux/systemd
* Tailscale
* nftables
* SOPS/age
* AppArmor
* Fail2Ban
* Blocky
* Prometheus
* Grafana
* Loki
* Alloy
* GitLab/GitOps
* Go services
* shell automation
* automated health checks
* automated rollback
* backups
* architecture enforcement
* TDD
* SRE practices

The architecture is governed by four fundamental rules:

> **Hosts compose capabilities.**
> **Domains own capabilities.**
> **Services expose contracts.**
> **Infrastructure adapters implement those contracts.**

The system therefore aims to avoid:

* undocumented coupling
* duplicated ownership
* hidden dependencies
* imperative configuration drift
* manually maintained service state
* insecure secret handling
* untested changes
* opaque deployment mechanisms
* single points of failure where practical
* AI-generated changes that bypass engineering controls

---

# 2. Infrastructure Architecture

## 2.1 High-Level Model

```text
                           GitLab
                             │
                             │
                      Source of Truth
                             │
                             ▼
                    ┌─────────────────┐
                    │    Ivali Flow   │
                    │ TDD + CI + MR   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ GitOps Control   │
                    │ Plane            │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Nix Flake       │
                    │ Evaluation      │
                    └────────┬────────┘
                             │
             ┌───────────────┼────────────────┐
             │               │                │
             ▼               ▼                ▼
          Prague          Tuscany          Test VM
          x86_64          x86_64           x86_64
             │
             │
       ┌─────┴──────────────────────────────────┐
       │                                        │
       ▼                                        ▼
 Security / Network                       Desktop Platform
       │                                        │
 Tailscale                                  KDE Plasma
 nftables                                    Wayland
 AppArmor                                    PipeWire
 SOPS/age                                    portals
 Fail2Ban                                   applications
 Blocky
       │
       └──────────────────┬─────────────────────┘
                          │
                          ▼
                    Observability
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
         Prometheus     Grafana       Loki
             │
             ▼
        Health / SRE
             │
             ▼
      Recovery / Rollback
```

---

## 2.2 Domain-Based Architecture

The repository is organized around architectural domains rather than arbitrary collections of files.

Major domains include:

* `boot`
* `hardware`
* `hosts`
* `home`
* `desktop`
* `developer`
* `networking`
* `security`
* `observability`
* `recovery`
* `services`
* `storage`
* `ssh`
* `system`
* `virtualization`
* `packages`
* `shared`
* `internal`
* `architecture`
* `automation`
* `scripts`
* `ci`

The exact implementation structure is defined by the repository itself and must not be inferred from historical documentation.

### Architectural Boundary

The desired dependency direction is:

```text
Host
  │
  ▼
Domain
  │
  ▼
Service Contract
  │
  ▼
Infrastructure Adapter
```

Not:

```text
Domain
  │
  └──► Specific Host
```

Hosts compose capabilities.

They should not become owners of domain logic.

---

# 3. The Nix Flake

## 3.1 What Is a Nix Flake?

A Nix Flake provides a reproducible interface for defining:

* inputs
* packages
* applications
* NixOS configurations
* checks
* development shells
* other reproducible outputs

The Ivali flake is the primary composition point for the infrastructure.

It provides the dependency graph from which hosts, packages, checks, and tooling are constructed.

---

## 3.2 Primary Inputs

The infrastructure uses the Nix ecosystem with `nixpkgs` tracking the desired unstable channel.

Typical foundational inputs include:

```nix
nixpkgs
home-manager
sops-nix
```

The exact versions and revisions are controlled by `flake.lock`.

### `flake.lock`

`flake.lock` is part of the reproducibility boundary.

It records resolved input revisions and content hashes so that infrastructure builds can be reproduced against the same dependency graph.

---

## 3.3 Host Composition

Host definitions are centrally registered and composed into `nixosConfigurations`.

The host layer determines things such as:

* hostname
* architecture
* hardware profile
* username
* enabled capabilities
* host-specific features
* Tailscale configuration
* desktop requirements
* service selections

The host itself should remain a composition layer.

---

## 3.4 Flake Outputs

The infrastructure exposes outputs such as:

| Output                | Purpose                         |
| --------------------- | ------------------------------- |
| `nixosConfigurations` | Complete NixOS configurations   |
| `packages`            | Buildable packages              |
| `checks`              | Automated validation            |
| `devShells`           | Development environments        |
| `apps`                | Executable infrastructure tools |

The exact current output set is defined by `flake.nix`.

Documentation must never claim an output exists without verifying it in the current repository.

---

# 4. NixOS Host Architecture

NixOS is the foundation of the infrastructure.

It provides declarative control over:

* kernel
* bootloader
* system packages
* systemd
* networking
* firewall
* users
* groups
* SSH
* security
* services
* hardware
* storage
* desktop integration
* virtualization
* system configuration

---

## 4.1 Prague

`prague` is the primary workstation/infrastructure host.

It combines:

* NixOS
* AMD hardware
* KDE Plasma
* developer tooling
* Tailscale
* security stack
* observability
* GitOps
* infrastructure control-plane services
* backup/recovery mechanisms

Prague is both:

1. a daily-use Linux workstation
2. an infrastructure control and operations node

This dual role requires particularly strong isolation between:

* desktop concerns
* infrastructure services
* privileged operations
* secrets
* deployment automation

---

## 4.2 Other Hosts

The repository also supports additional hosts such as:

* `tuscany`
* `testvm`

The authoritative host list must always be derived from the current repository rather than copied from historical documentation.

---

## 4.3 Host Templates

Reusable host capabilities should be expressed through reusable modules/templates rather than duplicated host configuration.

Examples include:

* laptop configuration
* hardware configuration
* networking
* desktop
* security
* observability
* development environment

This allows hosts to remain small composition files.

---

# 5. Home Manager

## 5.1 Purpose

Home Manager manages the user environment above the NixOS system layer.

The division is:

```text
NixOS
  └── Machine
      ├── Kernel
      ├── systemd
      ├── networking
      ├── security
      ├── services
      └── hardware

Home Manager
  └── User
      ├── Shell
      ├── Git
      ├── Editors
      ├── Applications
      ├── Firefox
      ├── KDE configuration
      ├── User services
      └── User-level environment
```

---

## 5.2 Design Principles

Home Manager configuration should be:

* declarative
* reproducible
* modular
* idempotent
* composable
* host-aware where necessary
* free from unnecessary imperative scripts

---

## 5.3 User Environment

The user environment includes infrastructure development tools such as:

* Zsh
* Git
* Git LFS
* delta
* fzf
* zoxide
* direnv
* Atuin
* eza
* bat
* btop
* fastfetch
* Go
* Node.js
* PHP
* Nix tooling
* container tooling
* infrastructure CLI tools

The exact package set must follow the current Home Manager configuration.

---

# 6. KDE Plasma Desktop

KDE Plasma is the supported desktop platform for the Ivali workstation.

The previous GNOME-oriented architecture is obsolete.

## 6.1 KDE as a Platform

KDE is treated as an integrated desktop platform rather than a collection of applications.

The desktop architecture includes:

* KDE Plasma
* KWin
* Wayland
* XWayland
* KDE portals
* PipeWire
* WirePlumber
* NetworkManager integration
* Bluetooth integration
* display management
* power management
* notifications
* clipboard
* file associations
* application launching
* remote desktop capabilities

---

## 6.2 Visual System

The desktop targets a cohesive, polished Linux workstation experience.

The current design direction includes:

* KDE Plasma
* Garuda Mokka-inspired visual styling
* consistent GTK/Qt theming
* clean typography
* coherent iconography
* minimal visual duplication
* sensible panel/dock configuration
* efficient application launcher
* keyboard-first workflows

The Garuda Mokka theme is treated as a presentation layer, not as an architectural dependency.

---

## 6.3 Firefox

Firefox remains the primary browser.

The browser environment includes:

* Sidebery
* vertical tabs
* privacy controls
* developer tooling
* web applications
* productivity integrations

Firefox configuration should remain reproducible through Home Manager where practical.

---

## 6.4 Office and Web Applications

The infrastructure favors native Linux applications and web applications where they provide the best reliability.

Microsoft 365 is treated as a web/cloud workload unless a specific compatibility requirement justifies a controlled Windows compatibility layer.

Any Wine/Bottles-based solution must be treated as an optional application compatibility layer rather than a core infrastructure dependency.

---

## 6.5 Desktop Reliability

Desktop infrastructure is subject to the same engineering standards as server infrastructure.

Critical desktop capabilities include:

* audio
* microphone
* Bluetooth
* Wi-Fi
* screen sharing
* cameras
* external displays
* suspend/resume
* portals
* notifications
* application launching
* remote GUI access

These are operational capabilities, not cosmetic features.

---

# 7. Linux Platform

NixOS abstracts configuration, but the underlying Linux system remains the actual runtime.

The infrastructure therefore requires Linux-level understanding.

## 7.1 Core Linux Components

The platform includes:

* Linux kernel
* systemd
* udev
* procfs
* sysfs
* cgroups
* namespaces
* capabilities
* sockets
* nftables
* NetworkManager
* PipeWire
* WirePlumber
* storage/filesystems
* PCI/USB devices
* ACPI
* firmware
* kernel modules

---

## 7.2 systemd

systemd is the primary service supervisor.

Services should define:

* ownership
* purpose
* dependencies
* privileges
* state directories
* configuration
* restart policy
* timeout behavior
* sandboxing
* health checks
* logs
* recovery behavior

A systemd unit is part of the operational architecture, not merely an implementation detail.

---

## 7.3 Resource Management

Resource-sensitive services should explicitly consider:

* CPU
* memory
* disk I/O
* network bandwidth
* process count
* file descriptors

The infrastructure favors predictable resource behavior over uncontrolled background workloads.

---

# 8. Security Architecture

Security is layered.

```text
                 ┌───────────────────┐
                 │ Identity / Access │
                 └─────────┬─────────┘
                           │
                 ┌─────────▼─────────┐
                 │ Tailscale / Zero  │
                 │ Trust             │
                 └─────────┬─────────┘
                           │
                 ┌─────────▼─────────┐
                 │ nftables Firewall │
                 └─────────┬─────────┘
                           │
              ┌────────────▼────────────┐
              │ systemd / Linux        │
              │ sandboxing             │
              └────────────┬────────────┘
                           │
          ┌────────────────▼────────────────┐
          │ AppArmor / privilege controls  │
          └────────────────┬────────────────┘
                           │
          ┌────────────────▼────────────────┐
          │ SOPS / age secrets             │
          └────────────────┬────────────────┘
                           │
          ┌────────────────▼────────────────┐
          │ Monitoring / Detection         │
          └────────────────┬────────────────┘
                           │
          ┌────────────────▼────────────────┐
          │ Backup / Recovery              │
          └─────────────────────────────────┘
```

Security is not delegated to one tool.

---

## 8.1 Security Principles

The infrastructure follows:

* least privilege
* defense in depth
* deny by default where practical
* identity-based access
* encrypted secrets
* explicit network exposure
* observable security controls
* recoverable security failures
* reproducible security configuration

---

# 9. SOPS and Secret Management

SOPS + age is the authoritative secret-management mechanism.

Secrets are:

1. encrypted in the repository
2. decrypted only by authorized systems
3. materialized into controlled runtime paths
4. consumed only by authorized services

Secrets must never be committed in plaintext.

---

## 9.1 Secret Boundary

```text
Encrypted Git Repository
          │
          ▼
       SOPS/age
          │
          ▼
   Authorized Host
          │
          ▼
     /run/secrets
          │
          ▼
 Authorized Service
```

Secrets should not be copied into:

* Git history
* shell scripts
* logs
* generated configuration
* public artifacts
* application source

---

## 9.2 Secret Rotation

Rotation must be deliberate and auditable.

Important credentials include:

* Tailscale credentials
* GitLab credentials
* SMTP credentials
* application secrets
* infrastructure tokens
* backup credentials
* host-specific secrets

The infrastructure should support detection of aging credentials and provide operator guidance for rotation.

---

# 10. Tailscale and Zero Trust

Tailscale is the primary private networking fabric.

The design follows Zero Trust principles:

* identity before access
* encrypted transport
* explicit authorization
* no assumption that LAN access equals trust
* minimized public exposure

---

## 10.1 Tailnet

The current tailnet domain is:

```text
codlet-trench.ts.net
```

The tailnet provides:

* secure host-to-host connectivity
* MagicDNS
* SSH access
* administrative access
* service access
* mobile connectivity
* exit-node capability
* private control-plane access

---

## 10.2 Prague Exit Node

Prague can operate as a Tailscale exit node.

This provides a full-tunnel path for authorized tailnet devices.

```text
Phone / Remote Device
        │
        │ Tailscale
        ▼
     Prague
   Exit Node
        │
        ▼
    Internet
```

Exit-node operation requires:

* IP forwarding
* correct nftables behavior
* correct reverse-path filtering
* Tailscale route advertisement
* health validation

The exit-node path must never be broken by generic egress filtering.

---

## 10.3 Tailscale SSH

Tailscale SSH may be used where explicitly enabled.

Otherwise, standard SSH can remain available over the Tailscale interface using:

* key authentication
* disabled password authentication
* disabled root login
* restrictive firewall rules

---

# 11. Network Security and nftables

Network security is implemented in layers.

## 11.1 Firewall

The firewall follows:

> **Expose only what is required.**

Potential exposed services include:

| Port  | Protocol | Purpose                                   |
| ----- | -------- | ----------------------------------------- |
| 41641 | UDP      | Tailscale WireGuard                       |
| 3478  | UDP      | STUN where required                       |
| 53317 | TCP/UDP  | LocalSend — Tailscale-only (not LAN)        |
| 53    | TCP/UDP  | Blocky, restricted to intended interfaces |

Actual ports must be verified against current Nix configuration.

---

## 11.2 Egress Filtering

Egress filtering is optional because aggressive default-deny egress can break:

* Nix
* Git
* Tailscale
* DNS
* time synchronization
* updates
* exit-node forwarding

Where enabled, egress policy must be:

* declarative
* observable
* idempotent
* dynamically refreshed where necessary
* compatible with Tailscale

---

## 11.3 Network Ownership

Every network port must have a clear owner.

The architecture must prevent:

```text
Module A → port 22
Module B → port 22
```

without an explicit architectural reason.

Network ownership is therefore part of architecture enforcement.

---

# 12. Blocky DNS

Blocky provides local DNS filtering.

Its responsibilities include:

* ad blocking
* tracker blocking
* malware-domain filtering
* DNS forwarding
* metrics
* tailnet DNS service

---

## 12.1 DNS Architecture

```text
Application
    │
    ▼
systemd-resolved
    │
    ▼
Blocky
    │
    ├── Blocklists
    │
    └── Upstream DNS
          ├── DoH
          └── DoT
```

Blocky should be reachable only from authorized interfaces.

---

## 12.2 Tailscale Integration

Blocky can provide filtered DNS to authorized tailnet devices.

This allows remote devices to benefit from the same DNS policy without exposing the resolver publicly.

---

## 12.3 AppArmor

Blocky is a suitable candidate for AppArmor confinement because its responsibilities are narrow and well-defined.

Its profile should allow only:

* required libraries
* configuration
* state
* network access
* metrics
* required runtime resources

---

# 13. Observability

Observability is an architectural capability, not an optional add-on.

The platform uses:

* Prometheus
* Grafana
* Loki
* Alloy
* application metrics
* system metrics
* structured health results
* service status
* logs

---

## 13.1 Observability Model

```text
                 Applications
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
      Metrics        Logs         Health
        │             │             │
        ▼             ▼             ▼
   Prometheus        Loki       Health API
        │             │             │
        └─────────────┼─────────────┘
                      ▼
                   Grafana
```

---

## 13.2 Observability Principle

Observability is primarily a **consumer** of system information.

It should not become the owner of another domain's state.

For example:

```text
Security → owns security state
Observability → observes security state
```

not:

```text
Observability → owns security state
Security → reads observability internals
```

---

## 13.3 Metrics

Metrics should expose operational facts such as:

* service health
* deployment status
* Tailscale state
* key expiry
* disk utilization
* CPU
* memory
* network
* backup status
* system generation
* security scanner results

---

# 14. GitOps and Continuous Reconciliation

GitLab is the infrastructure source of truth.

The desired operating model is:

```text
Change
  │
  ▼
Feature Branch
  │
  ▼
TDD
  │
  ▼
Validation
  │
  ▼
Merge Request
  │
  ▼
CI
  │
  ▼
Review / Approval
  │
  ▼
Merge
  │
  ▼
GitOps Reconciliation
  │
  ▼
Nix Build
  │
  ▼
Activation
  │
  ▼
Health Gate
  │
  ├── PASS → Continue
  │
  └── FAIL → Recovery / Rollback
```

---

## 14.1 Ivali Flow

The infrastructure uses the Ivali Flow as the controlled engineering lifecycle.

```text
UNDERSTAND
     ↓
CLASSIFY
     ↓
INVESTIGATE
     ↓
PLAN
     ↓
ISSUE
     ↓
BRANCH
     ↓
TEST / TDD
     ↓
IMPLEMENT
     ↓
VERIFY
     ↓
COMMIT
     ↓
PUSH
     ↓
MR
     ↓
CI
     ↓
REVIEW
     ↓
MERGE
     ↓
DEPLOY
     ↓
HEALTH CHECK
     ↓
OBSERVE
     ↓
REPORT
```

AI agents must operate inside this lifecycle.

They must not bypass repository governance.

---

# 15. Self-Healing and Recovery

Self-healing is implemented as multiple independent layers.

```text
Layer 1  systemd restart
Layer 2  service health checks
Layer 3  deployment health
Layer 4  deployment rollback
Layer 5  GitOps reconciliation
Layer 6  network recovery
Layer 7  backup restoration
```

---

## 15.1 Systemd Recovery

Critical services should use appropriate restart policies.

Examples include:

```text
Restart=on-failure
Restart=always
RestartSec=5s
```

The exact policy must be selected according to service behavior.

Restarting a fundamentally broken service indefinitely is not considered sufficient recovery.

---

## 15.2 Deployment Health

Deployment health evaluates:

### System

* systemd
* boot state
* generation
* NTP

### Network

* interfaces
* DNS
* Tailscale
* connectivity

### Services

* critical systemd units
* required infrastructure services
* application health

### Storage

* filesystem availability
* disk utilization
* backup availability

### Configuration

* Git repository
* flake evaluation
* worktree state
* expected generation

---

## 15.3 Rollback

Rollback is a first-class architectural capability.

A failed deployment must not leave the machine permanently in an unhealthy generation.

The rollback design uses:

* concurrency control
* health revalidation
* hysteresis
* generation tracking
* a single authoritative rollback mechanism
* post-rollback health verification

The system should prefer:

```text
Detect
  ↓
Re-check
  ↓
Classify
  ↓
Rollback if necessary
  ↓
Verify
  ↓
Notify
```

rather than immediately rolling back on the first transient failure.

---

# 16. Backup and Disaster Recovery

Backups are part of reliability engineering.

The infrastructure distinguishes:

* configuration recovery
* machine recovery
* application-data recovery
* secret recovery
* disaster recovery

---

## 16.1 Recovery Layers

### Layer 1 — Nix Generations

Provides rapid configuration rollback.

### Layer 2 — Git

Provides historical configuration recovery.

### Layer 3 — Application/Data Backups

Protects state that cannot be recreated from Nix.

### Layer 4 — Encrypted Off-Host Backup

Protects against host loss.

### Layer 5 — Disaster Recovery

Provides the procedure for rebuilding the infrastructure on replacement hardware.

---

## 16.2 Recovery Principle

A backup is not considered valid merely because it exists.

It must be:

* encrypted
* accessible
* restorable
* periodically verified
* documented

> **A backup that has never been restored is an assumption, not proof of recoverability.**

---

# 17. SRE Operating Model

SRE principles govern the infrastructure.

The system is operated around:

* reliability
* availability
* observability
* capacity
* performance
* recovery
* change safety
* automation
* incident response

---

## 17.1 Reliability

Reliability means the system behaves correctly over time.

Reliability work includes:

* health checks
* automated recovery
* rollback
* dependency management
* resource controls
* backup validation
* failure testing

---

## 17.2 Error Budgets

Where appropriate, reliability should be expressed through measurable objectives.

Examples:

* deployment success rate
* service availability
* backup success rate
* recovery time
* health-check failure rate
* mean time to recovery

The infrastructure should avoid inventing SLOs where no meaningful measurement exists.

---

## 17.3 Incident Model

Incidents should follow:

```text
Detect
  ↓
Triage
  ↓
Stabilize
  ↓
Diagnose
  ↓
Recover
  ↓
Verify
  ↓
Document
  ↓
Prevent recurrence
```

The objective is not merely to restore service.

The objective is to reduce the probability of recurrence.

---

## 17.4 Operational Simplicity

Every new service creates:

* another failure mode
* another security boundary
* another configuration surface
* another dependency
* another monitoring requirement

Therefore:

> **Do not add infrastructure merely because it is technically possible.**

---

# 18. TDD and Verification

Testing is part of infrastructure development.

The preferred workflow is:

```text
Write Test
    ↓
Run Test
    ↓
RED
    ↓
Implement
    ↓
Run Test
    ↓
GREEN
    ↓
Refactor
    ↓
Verify
```

---

## 18.1 Bug Fixes

A bug fix should follow:

```text
Reproduce
    ↓
Write Regression Test
    ↓
RED
    ↓
Fix
    ↓
GREEN
    ↓
Regression Verification
```

This applies to:

* Go
* Nix
* shell
* networking
* systemd
* security
* desktop integration
* deployment logic

---

## 18.2 NixOS Verification

Typical verification layers include:

```text
nix fmt
    ↓
architecture tests
    ↓
architecture linter
    ↓
Go tests/build/vet
    ↓
Nix flake check
    ↓
host evaluation
    ↓
build
    ↓
activation
    ↓
runtime health
```

The exact commands are determined by the current repository.

---

## 18.3 Desktop Verification

KDE changes should verify:

* Plasma starts
* KWin starts
* Wayland session works
* applications launch
* audio works
* microphone works
* Bluetooth works
* Wi-Fi works
* portals work
* screen sharing works
* external displays work
* suspend/resume works
* remote GUI access works where configured

---

# 19. Architecture Governance

The architecture is machine-enforced where possible.

Machine-readable architecture information lives under:

```text
architecture/
```

including:

```text
architecture/domains.yaml
architecture/dependencies.yaml
architecture/exceptions.yaml
```

---

## 19.1 Architectural Invariants

The infrastructure enforces principles including:

### Domain validity

Only declared domains may participate in the architecture.

### Dependency direction

Dependencies must follow the approved graph.

### Cycle detection

Architectural cycles are prohibited unless explicitly justified.

### Filesystem ownership

A state path has one authoritative owner.

### Configuration ownership

Configuration should have one authoritative owner.

### Duplicate ownership

Two modules must not silently claim the same responsibility.

### Declared dependencies

Dependencies must be explicit.

### Internal API boundaries

Internal service boundaries must be respected.

### Service state ownership

Runtime state must have an explicit owner.

---

## 19.2 Architecture Exceptions

Exceptions are explicit and documented.

They must include:

* identifier
* justification
* affected components
* owner
* scope
* status
* review requirements

An exception is not permission to ignore architecture indefinitely.

---

# 20. The Tailnet

The tailnet is the private communication plane.

```text
                         Tailscale
                      Coordination Plane
                              │
              ┌───────────────┼───────────────┐
              │               │               │
           Prague          Mobile          Oracle Edge
              │               │               │
              └───────────────┼───────────────┘
                              │
                         Private Mesh
```

---

## 20.1 Services Over the Tailnet

The tailnet may provide access to:

* SSH
* infrastructure APIs
* dashboards
* health endpoints
* Grafana
* Prometheus
* administrative interfaces
* Blocky DNS
* remote desktop
* emergency management

Services should not be exposed publicly when Tailscale can provide the required access boundary.

---

## 20.2 Public Exposure

Public internet exposure should be considered an exception.

For every public service ask:

1. Does it actually need to be public?
2. Can Tailscale provide access?
3. Can authentication be strengthened?
4. Can the service be isolated?
5. Can exposure be monitored?
6. Can it be recovered?

---

# 21. Oracle Edge Architecture

A planned ARM64 Oracle node extends the infrastructure without becoming a second full workstation.

The intended node is:

```text
oracle-edge
Architecture: ARM64
Desktop: none
Primary purpose: infrastructure edge/control plane
```

---

## 21.1 Oracle Edge Responsibilities

The node is intended to provide lightweight always-on capabilities such as:

* Tailscale
* SSH emergency access
* external monitoring
* watchdog services
* backup exit-node capability
* encrypted backup storage
* age/SOPS emergency recovery material
* webhook reception
* API gateway
* alerting
* always-on infrastructure web UI

---

## 21.2 Relationship With Prague

Oracle Edge is not intended to replace Prague.

The relationship is:

```text
                  ┌─────────────┐
                  │  Oracle     │
                  │  Edge       │
                  │  ARM64      │
                  └──────┬──────┘
                         │
                  Tailscale Mesh
                         │
                  ┌──────▼──────┐
                  │   Prague    │
                  │   Primary   │
                  │   Node      │
                  └─────────────┘
```

Oracle Edge provides independence from Prague so that a failure of the primary workstation does not eliminate every control path.

---

## 21.3 Security Model

Oracle Edge should have:

* no desktop environment
* minimal packages
* minimal listening ports
* Tailscale-first access
* SSH hardening
* encrypted backups
* strict firewall
* systemd sandboxing
* monitoring
* alerting
* immutable/declarative configuration where practical

---

# 22. System Autonomy

The infrastructure is designed as an autonomous control loop.

```text
                 ┌─────────────────┐
                 │ Desired State   │
                 │ GitLab / Nix    │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ GitOps          │
                 │ Reconciliation  │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Build / Apply   │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Health Gate     │
                 └───────┬─────────┘
                         │
              ┌──────────┴──────────┐
              │                     │
            PASS                   FAIL
              │                     │
              ▼                     ▼
           Observe               Recover
              │                     │
              │               ┌─────▼─────┐
              │               │ Rollback  │
              │               └─────┬─────┘
              │                     │
              └──────────┬──────────┘
                         ▼
                    Report / Alert
```

---

## 22.1 What Is Automated?

The system may automatically:

* reconcile configuration
* evaluate Nix
* build generations
* activate configurations
* run health checks
* restart failed services
* perform safe rollback
* monitor certificates/keys
* monitor security
* collect metrics
* collect logs
* perform backups
* clean resources
* detect configuration drift
* notify operators

---

## 22.2 What Requires Human Judgment?

Human authorization remains appropriate for:

* major architecture changes
* security-policy weakening
* destructive data operations
* credential revocation/rotation with external impact
* new production trust relationships
* accepting significant architecture exceptions
* irreversible migrations
* changes with substantial availability risk

Automation should reduce routine operational work without removing human control over consequential decisions.

---

# 23. Operational Interfaces

The `ivali` control plane provides a unified interface to infrastructure operations.

Conceptually:

```text
ivali
 ├── status
 ├── health
 ├── doctor
 ├── metrics
 ├── dashboard
 ├── reconcile
 ├── rebuild
 ├── rollback
 ├── deploy
 └── api
```

The exact current command set must be verified against the implementation.

---

## 23.1 CLI

The CLI is intended to provide:

* operator visibility
* health information
* diagnostics
* controlled infrastructure actions
* machine-readable output
* consistent operational workflows

---

## 23.2 Web Control Plane

The infrastructure may expose a web control plane for:

* status
* health
* deployments
* service state
* observability
* diagnostics
* recovery actions

The web interface must not bypass the same authorization and architecture boundaries as the CLI.

---

## 23.3 Mobile / Remote Access

The system is designed to support secure remote administration through:

* Tailscale
* SSH
* mobile Tailscale clients
* secure GUI remote access
* emergency Oracle Edge access

Remote access should never require opening unnecessary services to the public internet.

---

# 24. Failure and Recovery Model

Infrastructure failures are classified rather than treated uniformly.

## 24.1 Failure Classes

### Configuration Failure

Examples:

* invalid Nix expression
* broken module option
* architecture violation

Response:

```text
Test → reject change
```

---

### Build Failure

Examples:

* dependency failure
* package failure
* evaluation failure

Response:

```text
CI/build gate → reject deployment
```

---

### Deployment Failure

Examples:

* service fails after activation
* network breaks
* KDE session breaks
* required service fails

Response:

```text
Health gate
   ↓
Recovery
   ↓
Rollback if required
```

---

### Runtime Failure

Examples:

* service crash
* disk exhaustion
* network failure
* DNS failure

Response:

```text
Detection
   ↓
systemd / remediation
   ↓
health verification
   ↓
operator notification if unresolved
```

---

### Host Failure

Examples:

* disk failure
* hardware failure
* unrecoverable OS state

Response:

```text
Replacement hardware
       ↓
NixOS bootstrap
       ↓
Git checkout
       ↓
Secrets recovery
       ↓
Host rebuild
       ↓
Restore state
       ↓
Health verification
```

---

# 25. Infrastructure Lifecycle

Every infrastructure change follows a controlled lifecycle.

```text
1. Understand
2. Classify
3. Investigate
4. Identify architecture boundaries
5. Define acceptance criteria
6. Create issue
7. Create feature branch
8. Write tests
9. Prove RED
10. Implement
11. Prove GREEN
12. Refactor
13. Run architecture validation
14. Run local verification
15. Commit through Ivali Flow
16. Push through Ivali Flow
17. Open MR
18. CI validation
19. Review
20. Merge
21. GitOps reconciliation
22. Deploy
23. Health gate
24. Observe
25. Roll back if required
26. Report outcome
27. Update documentation
```

---

## 25.1 AI Engineering Rules

AI agents operating on this infrastructure must:

* read repository guidance first
* understand architecture before editing
* inspect actual files
* never invent repository state
* never claim tests passed without running them
* never claim deployment succeeded without evidence
* use TDD for behavior changes
* preserve architecture boundaries
* avoid unnecessary dependencies
* avoid unnecessary services
* avoid secret exposure
* avoid destructive operations without authorization
* use the Ivali Flow for Git lifecycle
* document meaningful architectural changes

AI is treated as an engineering participant, not as an unrestricted code generator.

---

# 26. Definition of Done

An infrastructure change is not complete merely because the code compiles.

A change is complete when it satisfies the applicable dimensions below.

## Correctness

The intended behavior works.

## Reproducibility

The system can be recreated from declarative configuration.

## Testability

Relevant behavior is covered by tests or deterministic verification.

## Architecture

The change respects domain boundaries and ownership.

## Security

Privileges, secrets, network exposure, and trust boundaries are appropriate.

## Observability

The system provides enough information to determine whether it is healthy.

## Recoverability

Failure has a defined recovery path.

## Operability

An operator can understand and manage the resulting system.

## Performance

The change does not introduce unacceptable resource consumption.

## Documentation

Important behavior and operational procedures are documented.

## CI

Required automated gates pass.

## Deployment

The change has been safely activated where deployment is in scope.

## Health

Post-deployment health has been verified.

---

# Final Infrastructure Model

The Ivali infrastructure can be summarized as:

```text
                        ┌─────────────────────┐
                        │       GitLab        │
                        │  Source of Truth    │
                        └──────────┬──────────┘
                                   │
                              Ivali Flow
                                   │
                         TDD + Architecture
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │      Nix Flake      │
                        │ Reproducible State  │
                        └──────────┬──────────┘
                                   │
                  ┌────────────────┼────────────────┐
                  │                │                │
                  ▼                ▼                ▼
              NixOS             Home             Hosts
                               Manager
                  │
       ┌──────────┼─────────────┐
       │          │             │
       ▼          ▼             ▼
    Security   Networking     Desktop
       │          │             │
       │       Tailscale      KDE Plasma
       │       nftables        KWin
       │       Blocky          Wayland
       │          │            PipeWire
       │          │            Portals
       │          │
       └──────────┼──────────────┐
                  │              │
                  ▼              ▼
             Observability    GitOps
                  │              │
                  └──────┬───────┘
                         ▼
                    Health Gates
                         │
                    ┌────┴────┐
                    │         │
                  Healthy   Failure
                    │         │
                    ▼         ▼
                 Observe   Recover
                              │
                         ┌────▼────┐
                         │Rollback │
                         └────┬────┘
                              │
                              ▼
                         Verify / Alert
```

The resulting infrastructure is designed around a simple operational equation:

> **Correctness + Reproducibility + Security + Observability + Recoverability + Testability + Architecture + Operational Simplicity = Production-Quality Infrastructure**

The ultimate objective is not merely to have a working NixOS machine.

It is to have an infrastructure platform that can:

* explain itself
* test itself
* monitor itself
* recover itself
* reproduce itself
* secure itself
* evolve safely
* and remain understandable to its operator.

