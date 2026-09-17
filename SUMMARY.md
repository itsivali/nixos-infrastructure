# Ivali NixOS Infrastructure — Complete System Summary

**Repository:** `willisivali/nixos-infrastructure`
**Owner:** Willis Ivali (`ivali`)
**Primary Host:** `prague`
**Operating System:** NixOS
**Architecture:** `x86_64-linux`
**Primary User:** `ivali`
**Timezone:** `Africa/Nairobi`
**Source of Truth:** GitLab repository
**Control Plane:** Go-based `ivali` platform/control plane
**Configuration Model:** NixOS + Home Manager + declarative domain modules
**Architecture Model:** Domain-oriented, contract-driven, machine-enforced
**Deployment Model:** GitOps + controlled reconciliation + health validation + rollback
**Desktop Platform:** KDE Plasma
**Documentation Status:** Living system reference

> **Important:** This document is a system summary, not a substitute for the repository source code, architecture manifests, tests, or operational procedures. When this document conflicts with executable repository behavior, the repository and its verification results are authoritative.

---

# 1. Executive Summary

The Ivali NixOS Infrastructure repository is a **declarative, reproducible, security-conscious, observable, GitOps-managed personal infrastructure platform** built around NixOS.

It combines:

* NixOS declarative system configuration;
* Home Manager;
* domain-oriented module architecture;
* automatic module discovery;
* multi-host composition;
* a Go control plane and CLI;
* GitOps reconciliation;
* deployment health validation;
* rollback and recovery;
* security hardening;
* SOPS/age secret management;
* Tailscale networking;
* observability;
* infrastructure testing;
* architecture enforcement;
* AI-assisted engineering;
* KDE Plasma desktop integration.

The system is designed around a fundamental principle:

> **The repository is the desired state; the control plane makes that desired state operational; verification determines whether the resulting system is actually healthy.**

The architecture therefore separates:

```text
Desired State
     │
     ▼
NixOS / Home Manager
     │
     ▼
System Configuration
     │
     ▼
Deployment / Reconciliation
     │
     ▼
Running System
     │
     ▼
Health / Metrics / Logs / Security
     │
     ▼
Control Plane
     │
     └──────► Recovery / Rollback
```

The goal is not merely automation.

The goal is **correct, reproducible, observable, recoverable automation**.

---

# 2. System Philosophy

The infrastructure is built around several engineering invariants.

## 2.1 Declarative First

NixOS is the source of truth for operating-system configuration.

Configuration should be expressed declaratively whenever possible.

Avoid imperative drift such as:

```text
manual package installation
manual systemd configuration
manual firewall changes
manual configuration edits
manual service mutation
```

when the behavior can be represented in Nix.

---

## 2.2 Architecture Before Implementation

Before adding functionality, determine:

* ownership;
* domain;
* dependencies;
* state;
* filesystem access;
* network exposure;
* secrets;
* observability;
* recovery;
* testing.

The repository uses machine-readable architecture metadata and automated validation to prevent architectural drift.

---

## 2.3 Hosts Compose Capabilities

Hosts should primarily compose domains.

```text
HOST
 │
 ├── BOOT
 ├── HARDWARE
 ├── NETWORKING
 ├── SECURITY
 ├── DESKTOP
 ├── DEVELOPER
 ├── OBSERVABILITY
 ├── AUTOMATION
 ├── RECOVERY
 ├── STORAGE
 ├── SERVICES
 ├── SSH
 ├── VIRTUALIZATION
 └── SYSTEM
```

Hosts should not become giant implementation files.

---

## 2.4 Domains Own Capabilities

Each domain has a defined responsibility.

Examples:

```text
security
    └── security controls

networking
    └── connectivity and network policy

desktop
    └── Linux desktop platform

observability
    └── telemetry and monitoring

recovery
    └── health and recovery mechanisms

automation
    └── reconciliation and automation

services
    └── application services
```

---

## 2.5 Services Expose Contracts

The Go control plane uses service contracts to prevent direct coupling between unrelated components.

The intended pattern is:

```text
Command / Application
        │
        ▼
Service Interface
        │
        ▼
Infrastructure Implementation
        │
        ▼
Operating System / External System
```

Examples include:

* notification;
* backup;
* metrics;
* health;
* platform operations.

---

## 2.6 One Owner Per Resource

The repository follows the invariant:

> **One state path → one owner.**

The same principle applies to:

* ports;
* configuration;
* secrets;
* systemd services;
* persistent state;
* firewall rules;
* network policy.

Duplicate ownership is architectural debt and should be detected rather than tolerated.

---

# 3. High-Level Architecture

```text
┌───────────────────────────────────────────────────────────────────────┐
│                         HUMAN / OPERATOR                              │
│                                                                       │
│                    Ivali Flow / CLI / SSH / KDE                      │
└────────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────────────────────────────────────────────────────────┐
│                          CONTROL PLANE                                 │
│                                                                       │
│  ┌───────────────┐  ┌────────────────┐  ┌─────────────────────────┐ │
│  │   ivali CLI   │  │ GitOps /       │  │ Health / Recovery       │ │
│  │               │  │ Reconciliation │  │                         │ │
│  └───────────────┘  └────────────────┘  └─────────────────────────┘ │
│                                                                       │
│  Platform │ Health │ Backup │ Metrics │ Notifications │ Deployment   │
└────────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────────────────────────────────────────────────────────┐
│                       NIXOS CONFIGURATION                              │
│                                                                       │
│  Flake → Host → Domains → Modules → NixOS Options → System           │
│                                                                       │
│  ┌────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌────────────┐ │
│  │ Boot   │ │ Network  │ │ Security │ │ Desktop    │ │ Services   │ │
│  └────────┘ └──────────┘ └──────────┘ └────────────┘ └────────────┘ │
│                                                                       │
│  ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌────────────────────┐ │
│  │ Developer  │ │ Recovery   │ │ Storage  │ │ Observability      │ │
│  └────────────┘ └────────────┘ └──────────┘ └────────────────────┘ │
└────────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────────────────────────────────────────────────────────┐
│                           RUNNING SYSTEM                               │
│                                                                       │
│ Linux kernel │ systemd │ KDE │ NetworkManager │ PipeWire │ Services  │
│                                                                       │
│ Tailscale │ nftables │ AppArmor │ SOPS │ Storage │ Containers        │
└────────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY / SECURITY                            │
│                                                                       │
│ Metrics │ Logs │ Traces │ Runtime Security │ Health │ Alerts         │
└────────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
                         Recovery / Rollback
```

---

# 4. Repository Architecture

The repository is organized around capability domains rather than arbitrary collections of files.

```text
nixos-infrastructure/
│
├── flake.nix
├── configuration.nix
│
├── hosts/
├── boot/
├── hardware/
├── networking/
├── security/
├── desktop/
├── developer/
├── observability/
├── automation/
├── recovery/
├── storage/
├── services/
├── ssh/
├── ci/
├── virtualization/
├── cloud/
├── i18n/
│
├── home/
├── packages/
├── shared/
├── system/
│
├── internal/
├── scripts/
├── tests/
├── architecture/
│
├── lib/
├── opencode/
├── secrets/
│
├── AGENTS.md
├── ENGINEERING.md
├── IVALi_FLOW.md
├── ARCHITECTURE.md
├── ARCHITECTURE_AUDIT.md
├── ARCHITECTURE_PROGRESS.md
├── MODULES.md
└── SUMMARY.md
```

The exact current tree is always authoritative.

---

# 5. NixOS Configuration Model

The system uses a Flake-based architecture.

Conceptually:

```text
flake.nix
    │
    ▼
nixosConfigurations
    │
    ▼
host composition
    │
    ▼
domain modules
    │
    ▼
NixOS configuration
```

The repository supports multiple hosts while allowing individual machines to compose only the capabilities they require.

---

# 6. Module System

The repository uses a **zero-touch auto-import model**.

The central implementation is:

```text
lib/auto-imports.nix
```

Domain entry points use the shared importer to discover modules automatically.

Example:

```text
security/
├── default.nix
├── firewall.nix
├── apparmor.nix
├── fail2ban.nix
├── hardening.nix
├── sops.nix
└── tailscale.nix
```

Adding a normal module does not require manually editing a central import registry.

The `_` prefix is reserved for private/helper content:

```text
_common.nix
_options.nix
_lib/
```

Auto-importing is a composition mechanism, not an architectural authorization mechanism.

---

# 7. Multi-Host Architecture

The repository is designed for multiple NixOS systems.

Current and planned host concepts include:

| Host          | Role                                          |
| ------------- | --------------------------------------------- |
| `prague`      | Primary NixOS laptop                          |
| `tuscany`     | Additional host/environment                   |
| `testvm`      | Test environment                              |
| `oracle-edge` | Planned lightweight ARM64 infrastructure node |

Host-specific configuration belongs at the host boundary.

Generic domains should not become polluted with unnecessary host-specific conditionals.

---

# 8. Primary Host — Prague

`prague` is the primary workstation and infrastructure node.

It serves multiple roles:

```text
Developer workstation
        +
NixOS infrastructure node
        +
Control-plane host
        +
GitOps endpoint
        +
Tailscale endpoint
        +
Observability endpoint
        +
Administrative workstation
```

This makes reliability particularly important.

A failure in one subsystem should not unnecessarily compromise unrelated capabilities.

---

# 9. Desktop Platform — KDE Plasma

The desktop architecture uses **KDE Plasma**.

KDE is treated as a complete Linux desktop platform rather than a collection of individual packages.

The desktop architecture separates:

```text
desktop/
├── common/
│   ├── audio
│   ├── GPU
│   ├── portals
│   ├── Bluetooth
│   └── display infrastructure
│
├── kde/
│   ├── Plasma
│   ├── session
│   ├── theme
│   ├── input
│   ├── power
│   └── desktop integration
│
└── login/
```

The desktop stack is expected to integrate correctly with:

* Wayland;
* KDE Plasma;
* KWin;
* PipeWire;
* WirePlumber;
* portals;
* NetworkManager;
* Bluetooth;
* AMD graphics;
* external displays;
* suspend/resume;
* screen sharing;
* microphone and camera access;
* remote administration.

Desktop configuration must be evaluated as a complete system.

---

# 10. Linux Platform Engineering

The infrastructure treats Linux below the Nix abstraction as an explicit engineering domain.

The AI/operator must understand:

* Linux kernel behavior;
* systemd;
* journald;
* udev;
* procfs;
* sysfs;
* cgroups;
* namespaces;
* capabilities;
* filesystems;
* permissions;
* ACLs;
* sockets;
* processes;
* signals;
* networking;
* DNS;
* routing;
* nftables;
* device management;
* power management;
* suspend/resume;
* boot process.

NixOS describes the desired configuration.

Linux determines the runtime behavior.

Both must be understood.

---

# 11. Boot and Kernel

The boot stack is responsible for:

* bootloader;
* kernel;
* initrd;
* kernel parameters;
* zRAM;
* sysctl;
* hardware initialization;
* TPM behavior;
* early security controls.

The exact current kernel configuration must always be verified from the repository rather than inferred from historical documentation.

Kernel changes are considered high-impact changes because they can affect:

* boot;
* hardware compatibility;
* graphics;
* networking;
* security;
* power;
* storage.

---

# 12. Hardware

Hardware configuration is separated from generic system configuration.

The hardware layer may cover:

* AMD GPU;
* Wi-Fi;
* USB;
* power management;
* display hardware;
* audio devices;
* laptop-specific quirks;
* kernel modules;
* device initialization.

Hardware debugging should use actual Linux evidence:

```text
lspci
lsusb
dmesg
journalctl
udevadm
/sys
/proc
systemctl
```

rather than guessing from Nix configuration alone.

---

# 13. Networking

The networking stack is built around Linux-native networking and NetworkManager.

Core responsibilities include:

* NetworkManager;
* DNS;
* systemd-resolved;
* routing;
* Tailscale;
* firewall interaction;
* time synchronization;
* network diagnostics.

Networking changes must consider interactions between:

```text
NetworkManager
systemd-resolved
Tailscale
nftables
DNS
routing
applications
```

A configuration that works in isolation but breaks Tailscale, DNS, Wi-Fi, or remote access is not considered correct.

---

# 14. Tailscale

Tailscale is a major component of the private network architecture.

The design supports:

* secure SSH;
* remote administration;
* private service access;
* exit-node functionality;
* infrastructure connectivity;
* administrative segmentation.

Tailscale configuration must be considered together with:

```text
nftables
SSH
routing
DNS
NetworkManager
systemd
remote GUI access
```

The security model must remain explicit.

---

# 15. Security Architecture

Security is defense-in-depth.

Relevant controls include:

```text
Linux kernel hardening
       │
       ▼
sysctl
       │
       ▼
nftables
       │
       ▼
SSH hardening
       │
       ▼
AppArmor
       │
       ▼
systemd sandboxing
       │
       ▼
SOPS / age
       │
       ▼
Tailscale access control
       │
       ▼
Fail2Ban
       │
       ▼
security scanning
       │
       ▼
observability
```

Security is not represented by a single package or module.

---

# 16. Security Engineering Responsibilities

The security architecture covers:

* host hardening;
* kernel hardening;
* sysctl policy;
* firewall policy;
* SSH;
* AppArmor;
* sudo;
* secret management;
* authentication;
* authorization;
* Tailscale;
* service sandboxing;
* dependency analysis;
* security scanning;
* auditability.

Security changes should consider:

```text
Confidentiality
Integrity
Availability
Least privilege
Defense in depth
Attack surface
Recovery
Auditability
```

---

# 17. Secrets Architecture

Secrets use SOPS/age.

The intended architecture is:

```text
Encrypted secret
       │
       ▼
SOPS / age
       │
       ▼
Authorized runtime consumer
       │
       ▼
Service
```

Secrets must never be:

* hard-coded;
* committed in plaintext;
* printed in logs;
* exposed in diagnostics;
* copied into unnecessary locations.

Secret access should follow least privilege.

---

# 18. Observability

Observability is treated as a first-class operational capability.

The stack may include:

| Component       | Responsibility                  |
| --------------- | ------------------------------- |
| Prometheus      | Metrics                         |
| Grafana         | Visualization                   |
| Loki            | Logs                            |
| Grafana Alloy   | Telemetry collection/forwarding |
| OpenTelemetry   | Telemetry pipelines             |
| Node Exporter   | Host metrics                    |
| NixOS exporter  | NixOS-specific metrics          |
| Falco           | Runtime security                |
| Health endpoint | Health state                    |

Exact enabled components must be verified against the current repository.

---

# 19. Observability Model

The target telemetry flow is:

```text
                         ┌──────────────┐
                         │    Grafana   │
                         └──────┬───────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
            Prometheus         Loki          Traces
                ▲               ▲               ▲
                │               │               │
        ┌───────┴──────┐       │        ┌───────┴──────┐
        │              │       │        │              │
   Node Exporter   NixOS     Alloy     OpenTelemetry
                  Exporter
                                ▲
                                │
                         systemd journal
```

Observability should consume system state.

It should not become the owner of unrelated system state.

---

# 20. SRE Model

The infrastructure follows SRE principles.

Important properties include:

### Reliability

The system should continue operating despite expected component failures.

### Observability

Failures should be detectable.

### Recoverability

Known failure modes should have recovery paths.

### Operability

An engineer should be able to understand and operate the system.

### Reproducibility

A system should be rebuildable from repository state.

### Change Safety

Changes should pass verification before deployment.

### Measurability

Important operational behavior should be observable.

---

# 21. Control Plane

The `ivali` Go application is the operational control plane.

Its purpose is not to replace NixOS.

Its purpose is to provide an operational interface over the infrastructure.

Conceptually:

```text
                   ivali
                     │
        ┌────────────┼────────────┐
        │            │            │
      Health      Platform     Deployment
        │            │            │
      Metrics      Backup      Recovery
        │            │            │
        └────────────┼────────────┘
                     │
                     ▼
                  NixOS
```

---

# 22. Control Plane Service Contracts

The architecture includes service contracts for core platform capabilities.

Examples:

```text
NotificationService
BackupService
MetricsProvider
HealthChecker
PlatformService
```

These contracts separate application logic from infrastructure implementations.

The intended Go architecture is:

```text
cmd
 │
 ▼
commands
 │
 ▼
application / orchestration
 │
 ▼
service interfaces
 │
 ▼
infrastructure adapters
```

Direct access to unrelated infrastructure state should be avoided.

---

# 23. `ivali` CLI

The CLI provides the primary operational interface.

Representative capabilities include:

```text
status
doctor
health
verify
scan
metrics
dashboard
explain
graph
docs
bootstrap
rebuild
update
suggest
deploy
reconcile
extract
```

The authoritative command set must be derived from the current source tree.

The CLI should provide:

* actionable diagnostics;
* machine-readable output where appropriate;
* safe operational commands;
* clear failure messages;
* health information;
* repository intelligence.

---

# 24. GitOps

Git is the desired-state source.

The reconciliation model is:

```text
Git repository
      │
      ▼
Desired configuration
      │
      ▼
Validation
      │
      ▼
Build
      │
      ▼
Deployment
      │
      ▼
Generation switch
      │
      ▼
Health validation
      │
      ├──── healthy ────► remain active
      │
      └──── unhealthy ──► recovery / rollback
```

GitOps must not blindly deploy unverified state.

---

# 25. Deployment Safety

Deployment is separate from code acceptance.

The preferred lifecycle is:

```text
Change
  ↓
TDD
  ↓
Local verification
  ↓
Ivali Flow
  ↓
CI
  ↓
Merge
  ↓
Reconciliation
  ↓
Build
  ↓
Generation switch
  ↓
Health validation
  ↓
Observation
  ↓
Rollback if required
```

A successful build does not necessarily mean a successful deployment.

A successful deployment does not necessarily mean a healthy system.

---

# 26. Recovery

Recovery is a first-class architecture domain.

Recovery mechanisms should cover:

* failed deployment;
* failed generation;
* failed service;
* degraded system;
* filesystem problems;
* networking failure;
* control-plane failure;
* observability failure;
* configuration regression.

The recovery philosophy is:

> **Detect → isolate → recover → verify → report.**

---

# 27. Backup

Backup is treated as an explicit platform capability rather than an incidental shell script.

Backup architecture should define:

* what is backed up;
* where it is stored;
* encryption;
* retention;
* verification;
* restoration;
* ownership;
* monitoring.

A backup that cannot be restored is not a reliable recovery mechanism.

---

# 28. Storage

Storage configuration covers:

* filesystems;
* mounts;
* BTRFS where applicable;
* snapshots;
* capacity;
* backup integration;
* recovery.

Storage changes are high-impact because they can affect:

* boot;
* data integrity;
* services;
* backups;
* recovery.

---

# 29. Services

Application services belong under `services/` when they represent independently managed system services.

Examples may include:

```text
nginx
postgresql
valkey
msmtp
```

Each service should have:

* clear ownership;
* configuration;
* state;
* dependencies;
* security policy;
* health checks;
* logs;
* recovery behavior.

---

# 30. Developer Environment

The developer environment is part of the infrastructure but should remain separated from core operating-system concerns.

Typical tooling includes:

```text
Nix
Go
Node.js
TypeScript
Python
Git
Zed
shell tooling
formatters
linters
debuggers
```

Development tooling should not unnecessarily become a dependency of the production control plane.

---

# 31. Home Manager

Home Manager owns user-level configuration.

Typical responsibilities include:

```text
Shell
Git
Editors
CLI tools
User environment
Fonts
User services
Desktop user configuration
```

The distinction is:

```text
NixOS
    → machine/system configuration

Home Manager
    → user/environment configuration
```

Avoid duplicating ownership between them.

---

# 32. Testing Architecture

The repository uses multiple testing layers.

```text
Unit tests
    │
    ▼
Architecture tests
    │
    ▼
Nix evaluation
    │
    ▼
Flake checks
    │
    ▼
NixOS integration / VM tests
    │
    ▼
Build verification
    │
    ▼
Runtime health
```

Different layers prove different properties.

No single test replaces the others.

---

# 33. Architecture Enforcement

Machine-readable architecture information is maintained under:

```text
architecture/
├── domains.yaml
├── dependencies.yaml
└── exceptions.yaml
```

Architecture validation is intended to detect:

* invalid domains;
* circular dependencies;
* forbidden imports;
* filesystem boundary violations;
* duplicate ownership;
* undeclared dependencies;
* internal API boundary violations;
* state ownership violations;
* invalid exceptions;
* host/domain boundary violations.

The architecture should progressively move from:

```text
implicit
   ↓
documented
   ↓
machine-readable
   ↓
tested
   ↓
CI-enforced
   ↓
self-protecting
```

---

# 34. AI Engineering Architecture

AI agents are first-class engineering participants but are constrained by repository governance.

The AI must understand:

```text
AGENTS.md
IVALi_FLOW.md
MODULES.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
architecture/*
opencode/*
```

The AI should behave as a:

> **Principal NixOS Engineer + Linux Systems Engineer + KDE Engineer + Security Engineer + SRE + Platform Architect**

rather than as a code autocomplete engine.

---

# 35. AI Engineering Rules

The AI must:

* inspect before changing;
* search before creating;
* understand ownership;
* respect architecture;
* write tests before behavior changes;
* prove failures before fixing bugs;
* verify its changes;
* never invent repository state;
* never claim tests passed without running them;
* never claim deployment succeeded without evidence;
* never bypass architectural controls;
* never weaken security merely to make a feature work;
* never create duplicate configuration unnecessarily;
* never introduce secrets into source;
* never bypass Ivali Flow.

---

# 36. Ivali Flow

All meaningful engineering work follows:

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
MERGE
    ↓
DEPLOY
    ↓
HEALTH CHECK
    ↓
OBSERVE
```

Git lifecycle operations should be performed through the repository's approved `ivali flow` process.

---

# 37. Security Audit Model

Security auditing should evaluate multiple layers.

```text
Repository
    │
    ├── Dependencies
    ├── Secrets
    ├── Nix configuration
    ├── systemd
    ├── Linux kernel
    ├── Firewall
    ├── SSH
    ├── AppArmor
    ├── Tailscale
    ├── Containers
    ├── Filesystem permissions
    └── Runtime behavior
```

A security audit should distinguish:

```text
configuration weakness
implementation weakness
operational weakness
architectural weakness
documentation weakness
runtime exposure
```

---

# 38. Remote Administration

Remote administration is designed around secure private connectivity.

Primary principles:

* Tailscale-first access;
* SSH hardening;
* least privilege;
* explicit firewall policy;
* secure GUI access where required;
* no unnecessary public exposure.

Remote GUI access must preserve the security boundary established for SSH and Tailscale.

---

# 39. Oracle Edge Architecture

A planned `oracle-edge` node is intended to provide a lightweight ARM64 infrastructure counterpart to `prague`.

Its target role includes:

```text
No desktop
        │
        ├── Tailscale
        ├── SSH
        ├── Emergency access
        ├── Monitoring
        ├── Watchdog
        ├── Backup exit node
        ├── Encrypted backup
        ├── Web UI
        ├── API gateway
        └── Alerting/webhooks
```

It should remain:

* minimal;
* hardened;
* independently recoverable;
* low resource;
* remotely manageable.

The Oracle node must not become an uncontrolled dependency for `prague`.

---

# 40. Operational Dependency Philosophy

A critical principle is:

> **A control-plane dependency should not become a single point of failure for the system it controls.**

For example:

```text
Observability failure
    ≠
system failure
```

and:

```text
Control-plane failure
    ≠
NixOS configuration loss
```

and:

```text
GitOps failure
    ≠
loss of local recovery capability
```

The system must retain sufficient local recovery capability to diagnose and repair failures.

---

# 41. Configuration Ownership

Configuration should have one authoritative owner.

Examples include:

```text
Nix settings
firewall policy
SSH policy
Tailscale policy
DNS policy
service configuration
observability configuration
package policy
desktop configuration
```

If two modules configure the same concern, determine whether they are genuinely complementary or whether ownership has become duplicated.

---

# 42. Network Ownership

Every listener should be attributable.

For each port:

```text
Port
 ├── Process
 ├── Owner
 ├── Purpose
 ├── Interface
 ├── Firewall policy
 ├── Authentication
 ├── Monitoring
 └── Recovery
```

Unknown listeners are treated as an operational/security finding.

---

# 43. State Ownership

Persistent state must have:

```text
Owner
Purpose
Location
Permissions
Backup policy
Retention
Recovery procedure
Monitoring
```

Examples include:

```text
/var/lib/gitops
/var/lib/observability
/var/lib/prometheus
/var/lib/loki
/mnt/backup
```

Exact paths must be verified against the current repository.

---

# 44. Documentation Architecture

The repository intentionally separates different types of documentation.

| Document                   | Purpose                         |
| -------------------------- | ------------------------------- |
| `SUMMARY.md`               | System-level orientation        |
| `ARCHITECTURE.md`          | Intended architecture           |
| `ARCHITECTURE_AUDIT.md`    | Current conformance             |
| `ARCHITECTURE_PROGRESS.md` | Migration/progress tracking     |
| `MODULES.md`               | NixOS module architecture       |
| `IVALi_FLOW.md`            | Engineering/deployment workflow |
| `AGENTS.md`                | AI repository contract          |
| `ENGINEERING.md`           | Engineering standards           |
| `CONTRIBUTING.md`          | Contribution process            |
| `DOCS.md`                  | Generated documentation         |

This separation prevents one document from becoming the source of every kind of truth.

---

# 45. Source-of-Truth Hierarchy

When information conflicts, use this order:

```text
1. Current repository implementation
2. Executable tests
3. Architecture manifests
4. Architecture linter
5. Nix evaluation
6. Go tests/build
7. Runtime inspection
8. CI results
9. Documentation
10. Historical audit material
11. AI assumptions
```

Historical documentation must never override current executable evidence.

---

# 46. Operational Verification

A claim such as:

> “The system is healthy”

requires evidence.

Depending on the situation, evidence may include:

```text
systemctl status
journalctl
ivali health
ivali doctor
ivali verify
Nix evaluation
NixOS test results
Prometheus metrics
service health endpoints
network connectivity
filesystem state
security scan
```

The AI must never manufacture verification results.

---

# 47. Failure Handling

The operational model is:

```text
Detect
  ↓
Classify
  ↓
Reproduce
  ↓
Contain
  ↓
Diagnose
  ↓
Fix
  ↓
Test
  ↓
Deploy
  ↓
Validate
  ↓
Observe
```

For production-impacting failures:

```text
Detect
  ↓
Preserve evidence
  ↓
Assess blast radius
  ↓
Recover safely
  ↓
Verify
  ↓
Perform root-cause analysis
  ↓
Add regression protection
```

---

# 48. Performance Philosophy

Performance optimization must be evidence-driven.

Measure before changing.

Relevant measurements include:

```text
CPU
Memory
I/O
Disk latency
Network latency
Boot time
Service startup
Nix evaluation
Build time
Desktop responsiveness
GPU behavior
Power consumption
Thermal behavior
```

Avoid optimizing based purely on intuition.

---

# 49. Resource-Constrained Engineering

`prague` is a laptop and therefore resource efficiency matters.

The system should avoid unnecessary:

* background services;
* polling;
* duplicated telemetry;
* memory-heavy agents;
* unnecessary containers;
* unnecessary GUI components;
* redundant databases;
* excessive logging.

Reliability and security must be balanced against laptop resource constraints.

---

# 50. Fresh Installation Model

A fresh installation should be recoverable through repository-driven bootstrap procedures.

Conceptually:

```text
Fresh NixOS
    │
    ▼
Bootstrap
    │
    ▼
Repository
    │
    ▼
Hardware configuration
    │
    ▼
Host composition
    │
    ▼
Nix evaluation
    │
    ▼
System activation
    │
    ▼
Verification
```

Bootstrap scripts must be treated as production infrastructure.

They should be:

* deterministic;
* safe to inspect;
* fail-fast;
* idempotent where practical;
* explicit about destructive operations;
* compatible with the current repository architecture.

---

# 51. Key Operational Commands

The exact command surface must always be verified from the current CLI.

Representative commands include:

```bash
ivali status
ivali doctor
ivali health
ivali verify
ivali scan
ivali metrics
ivali dashboard
ivali explain <module>
ivali graph tree
ivali docs
ivali rebuild
ivali update
ivali deploy
ivali reconcile
```

Nix operations commonly include:

```bash
nix fmt
nix flake check --no-build
nix build
nix develop
nix eval
```

System operations may include:

```bash
systemctl
journalctl
networkctl
nmcli
ip
ss
nft
tailscale
```

These commands are operational tools, not substitutes for architectural understanding.

---

# 52. Verification Pipeline

The preferred verification order is:

```text
Format
  ↓
Architecture tests
  ↓
Architecture linter
  ↓
Go tests
  ↓
Go build
  ↓
Go lint
  ↓
Shell validation
  ↓
Nix evaluation
  ↓
Nix flake checks
  ↓
NixOS integration tests
  ↓
Build
  ↓
Runtime verification
  ↓
Health validation
```

The exact CI pipeline remains authoritative.

---

# 53. Definition of Done

A system change is not complete merely because the code exists.

A production-quality change should be:

```text
✓ Correct
✓ Architecturally valid
✓ Declarative
✓ Reproducible
✓ Tested
✓ Secure
✓ Observable
✓ Recoverable
✓ Documented where necessary
✓ Operationally understandable
✓ Verified against actual runtime behavior
```

For infrastructure changes:

> **“It evaluates” is not equivalent to “it works.”**

---

# 54. Current System Identity

The Ivali infrastructure should be understood as:

```text
                    IVAlI INFRASTRUCTURE

                         NixOS
                           │
            ┌──────────────┼──────────────┐
            │              │              │
         Platform        Security       Desktop
            │              │              │
         Linux          Tailscale        KDE
         systemd        nftables         KWin
         hardware       AppArmor         Wayland
            │              │              │
            └──────────────┼──────────────┘
                           │
                    Control Plane
                           │
             ┌─────────────┼─────────────┐
             │             │             │
          GitOps         Health        Recovery
             │             │             │
             └─────────────┼─────────────┘
                           │
                     Observability
                           │
                 Metrics / Logs / Alerts
                           │
                         SRE
```

This is not simply a NixOS configuration repository.

It is an **infrastructure platform**.

---

# 55. What Makes Ivali Infrastructure Distinct

The architecture combines several normally separate concerns:

### Declarative Infrastructure

NixOS defines desired system state.

### Platform Engineering

The Go control plane provides operational abstractions.

### GitOps

Git provides desired-state history and controlled reconciliation.

### SRE

Health, observability, recovery, and operational discipline are first-class concerns.

### Security Engineering

Security controls exist across the entire stack.

### Linux Engineering

Runtime behavior is understood below the Nix abstraction.

### KDE Engineering

The desktop is treated as an integrated Linux platform.

### Architecture Governance

Machine-readable rules prevent architectural drift.

### AI Engineering

AI agents operate under explicit repository governance and verification requirements.

---

# 56. Roadmap

The roadmap must distinguish between:

```text
Completed
In Progress
Planned
Proposed
```

rather than presenting all desired functionality as already implemented.

Potential future areas include:

* Oracle ARM64 infrastructure;
* stronger fleet management;
* backup/restore automation;
* additional architecture enforcement;
* SBOM and supply-chain security;
* expanded NixOS VM testing;
* container runtime alternatives;
* improved remote GUI administration;
* enhanced control-plane APIs;
* richer web UI;
* advanced recovery automation;
* additional cloud integration.

Each roadmap item becomes “completed” only after implementation and verification evidence exist.

---

# 57. System Completion Model

The long-term goal is:

```text
Declarative
    ↓
Reproducible
    ↓
Tested
    ↓
Observable
    ↓
Secure
    ↓
Recoverable
    ↓
GitOps-managed
    ↓
Architecture-enforced
    ↓
AI-operable
```

The final state is not “zero human involvement.”

The objective is:

> **Minimal routine intervention with strong human control over consequential decisions.**

---

# 58. Golden Principles

The entire repository can be reduced to the following principles:

1. **Nix is the desired-state engine.**
2. **Git is the source of truth.**
3. **Hosts compose capabilities.**
4. **Domains own capabilities.**
5. **Modules implement capabilities.**
6. **Services expose contracts.**
7. **Adapters implement infrastructure behavior.**
8. **One owner controls each state resource.**
9. **One owner controls each configuration concern.**
10. **One owner controls each network resource.**
11. **Secrets are encrypted and least-privilege.**
12. **Security is defense in depth.**
13. **Observability is mandatory for important operational behavior.**
14. **Recovery must be designed before failure occurs.**
15. **Tests prove behavior.**
16. **Architecture tests protect boundaries.**
17. **AI agents must verify rather than assume.**
18. **Deployments require health validation.**
19. **Rollback is a feature, not an afterthought.**
20. **Documentation must follow the implementation.**

---

# 59. Final Engineering Standard

The Ivali infrastructure standard is:

```text
Correctness
    +
Reproducibility
    +
Security
    +
Observability
    +
Recoverability
    +
Testability
    +
Architecture
    +
Operational Simplicity
    +
Performance
    +
Maintainability
    =
Production-Quality Infrastructure
```

The purpose of the repository is not to accumulate configuration.

It is to build an infrastructure system that can be:

> **understood, reproduced, tested, secured, deployed, observed, recovered, and evolved without losing architectural integrity.**

That is the standard every human engineer and AI agent working on the repository is expected to maintain.

---

## Document Authority

This file is a **living system summary**.

It should be updated when major architectural changes occur, but it must not become a manually maintained inventory of every implementation detail.

For detailed truth, consult:

```text
ARCHITECTURE.md
    → intended architecture

ARCHITECTURE_AUDIT.md
    → actual conformance

ARCHITECTURE_PROGRESS.md
    → migration status

MODULES.md
    → module composition

IVALi_FLOW.md
    → engineering workflow

AGENTS.md
    → AI operating contract

architecture/*
    → machine-readable architectural rules

repository source + tests
    → executable truth
```

**Final authority:**

> **If this summary says one thing and the executable repository proves another, the executable repository wins—and this document must be corrected.**

