# Ivali NixOS Infrastructure

[![CI](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml)
[![Go Lint](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml/badge.svg?job=go-lint\&branch=main)](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml?query=job%3Ago-lint)
[![Go Tests](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml/badge.svg?job=go-test\&branch=main)](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml?query=job%3Ago-test)
[![Shell Lint](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml/badge.svg?job=shellcheck\&branch=main)](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml?query=job%3Ashellcheck)
[![Security Scan](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml/badge.svg?job=go-security\&branch=main)](https://github.com/itsivali/nixos-infrastructure/actions/workflows/ci.yml?query=job%3Ago-security)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![NixOS 26.11](https://img.shields.io/badge/NixOS-26.11-blue.svg)](https://nixos.org)
[![Go 1.26](https://img.shields.io/badge/Go-1.26-00ADD8.svg)](https://go.dev)

**Declarative NixOS infrastructure for the Ivali platform.**

Reproducible. Secure. Observable. Testable. Recoverable. Operable.

**Primary host:** `prague`
**Primary user:** `ivali`
**Operating system:** NixOS 26.11
**Desktop:** KDE Plasma / Wayland
**Architecture:** `x86_64-linux`
**Control plane:** Go
**Infrastructure model:** Declarative NixOS + Home Manager + GitOps + SRE principles

---

## Table of Contents

* [What This Repository Is](#what-this-repository-is)
* [Engineering Principles](#engineering-principles)
* [Architecture at a Glance](#architecture-at-a-glance)
* [Technology Stack](#technology-stack)
* [Repository Structure](#repository-structure)
* [NixOS Architecture](#nixos-architecture)
* [KDE Desktop Architecture](#kde-desktop-architecture)
* [Linux and System Architecture](#linux-and-system-architecture)
* [Control Plane](#control-plane)
* [GitOps and Deployment](#gitops-and-deployment)
* [Testing and Verification](#testing-and-verification)
* [Security](#security)
* [Networking and Tailscale](#networking-and-tailscale)
* [Observability and SRE](#observability-and-sre)
* [Recovery and Self-Healing](#recovery-and-self-healing)
* [Secrets](#secrets)
* [Home Manager](#home-manager)
* [AI Engineering](#ai-engineering)
* [Development Workflow](#development-workflow)
* [Installation](#installation)
* [Daily Operations](#daily-operations)
* [Host Management](#host-management)
* [Documentation](#documentation)
* [Architecture Governance](#architecture-governance)
* [Roadmap](#roadmap)
* [License](#license)

---

# What This Repository Is

`nixos-infrastructure` is the declarative infrastructure repository for the Ivali computing environment.

The repository treats the laptop as an **engineered infrastructure platform**, rather than simply a Linux workstation.

Everything that should be reproducible is represented as code:

* operating-system configuration
* boot configuration
* Linux kernel configuration
* hardware behavior
* networking
* firewall policy
* Tailscale networking
* SSH
* secrets integration
* KDE Plasma desktop
* Wayland session
* audio and Bluetooth
* applications
* development environments
* user environment
* system services
* observability
* security controls
* backups
* recovery
* GitOps
* deployment
* health checking
* automation
* the `ivali` control plane
* architecture governance

The objective is simple:

> **A known-good system should be reproducible from the repository, observable while running, and recoverable when something goes wrong.**

---

# Engineering Principles

The repository is built around a small set of non-negotiable principles.

### 1. Declarative infrastructure

If infrastructure can be represented as code, it should be represented as code.

Avoid undocumented manual configuration whenever practical.

### 2. Reproducibility

The same repository state should produce the same intended system configuration.

Nix flakes provide the reproducibility boundary.

### 3. Test before implementation

New behavior follows:

```text
Requirement
    ↓
Test
    ↓
RED
    ↓
Implementation
    ↓
GREEN
    ↓
Refactor
    ↓
Verification
```

Bug fixes follow:

```text
Reported failure
    ↓
Reproduce
    ↓
Regression test
    ↓
RED
    ↓
Fix
    ↓
GREEN
    ↓
Regression verification
```

### 4. Architecture is executable

Architecture is not merely documentation.

Domain boundaries, dependencies, ownership, service contracts, and forbidden relationships should be represented in machine-readable manifests and validated by automated tests and architecture tooling.

### 5. One owner for one responsibility

Every important resource should have a clear owner.

This applies to:

* configuration
* filesystem state
* services
* ports
* secrets
* runtime state
* deployment authority
* recovery authority

### 6. Observability is part of the design

A service is not complete merely because it starts.

It should have appropriate:

* health checks
* logs
* metrics
* failure visibility
* recovery behavior
* operational documentation

### 7. Recovery is a feature

The system should know how to recover from expected failures.

Examples include:

* failed deployments
* unhealthy generations
* failed services
* network failures
* stale GitOps state
* resource exhaustion
* corrupted working state
* boot failures

### 8. Security by default

Security boundaries should be explicit and fail closed where appropriate.

### 9. Automation must remain observable

Automation should never become a black box.

Automated operations must leave enough evidence to answer:

* what happened?
* why did it happen?
* what changed?
* what generation is running?
* what failed?
* what recovery action occurred?

### 10. Human approval remains authoritative

Automation may perform well-defined operational actions, but material security, architecture, destructive-data, credential, or policy decisions remain subject to explicit human authorization.

---

# Architecture at a Glance

The system follows this architectural model:

```text
                         ┌──────────────────────┐
                         │       GitLab         │
                         │   Source of Truth    │
                         └──────────┬───────────┘
                                    │
                              Git change
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │    Ivali Flow        │
                         │ TDD / CI / Gates     │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │   Architecture      │
                         │   Validation        │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │      GitOps          │
                         │    Reconciler        │
                         └──────────┬───────────┘
                                    │
                                    ▼
                    ┌──────────────────────────────┐
                    │         NixOS Host           │
                    │                              │
                    │  ┌────────────────────────┐  │
                    │  │ Domains / Capabilities │  │
                    │  └───────────┬────────────┘  │
                    │              │               │
                    │  ┌───────────▼────────────┐  │
                    │  │ Service Contracts      │  │
                    │  └───────────┬────────────┘  │
                    │              │               │
                    │  ┌───────────▼────────────┐  │
                    │  │ Infrastructure Adapters│  │
                    │  └───────────┬────────────┘  │
                    │              │               │
                    │       Linux / systemd       │
                    │              │               │
                    │      KDE / Wayland          │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                          Health / Metrics / Logs
                                   │
                                   ▼
                         Recovery / Rollback
```

The fundamental invariant is:

> **Hosts compose capabilities. Domains own capabilities. Services expose contracts. Infrastructure adapters implement those contracts.**

---

# Technology Stack

| Layer               | Technology                                      |
| ------------------- | ----------------------------------------------- |
| OS                  | NixOS 26.11                                     |
| Configuration       | Nix                                             |
| Reproducibility     | Nix Flakes                                      |
| User configuration  | Home Manager                                    |
| Desktop             | KDE Plasma                                      |
| Display             | Wayland                                         |
| Login               | SDDM                                            |
| Window system       | KWin                                            |
| Audio               | PipeWire / WirePlumber                          |
| Networking          | NetworkManager                                  |
| DNS                 | systemd-resolved / configured DNS filtering     |
| Overlay network     | Tailscale                                       |
| Firewall            | nftables                                        |
| SSH                 | OpenSSH / Tailscale                             |
| Security            | AppArmor, fail2ban, kernel hardening, SOPS      |
| Secrets             | SOPS + age                                      |
| Control plane       | Go                                              |
| CLI                 | `ivali`                                         |
| Observability       | Prometheus, Grafana, Loki, Alloy, OpenTelemetry |
| Security monitoring | Falco / security scanning                       |
| Deployment          | GitOps                                          |
| CI                  | GitLab + mirrored GitHub validation             |
| Shell               | Zsh                                             |
| Editor              | Zed                                             |
| Browser             | Firefox + Sidebery                              |
| Storage             | BTRFS / Nix store / zRAM                        |
| Containerization    | Docker where required                           |
| Automation          | systemd + NixOS modules + Go + shell            |
| AI engineering      | OpenCode + repository-specific AI context       |

---

# Repository Structure

The repository is organized by **architectural domain**, not merely by technology.

```text
.
├── flake.nix
├── configuration.nix
│
├── hosts/                 # Host definitions and hardware
├── boot/                  # Kernel, bootloader, initrd, zRAM, sysctl
├── hardware/              # Hardware-specific behavior
├── networking/            # NetworkManager, DNS, networking policy
├── security/              # Firewall, SOPS, AppArmor, hardening
├── ssh/                   # SSH server/client configuration
│
├── desktop/               # KDE Plasma / Wayland desktop
├── home/                  # Home Manager configuration
├── developer/             # Development environments
├── packages/              # Package sets
│
├── services/              # Reusable infrastructure services
├── observability/         # Metrics, logs, traces and alerting
├── recovery/              # Health and recovery mechanisms
├── automation/            # GitOps and automation
├── ci/                    # CI-specific infrastructure
├── storage/               # Storage configuration
├── virtualization/        # Containers/virtualization
├── system/                # Core NixOS system configuration
│
├── internal/              # Go control-plane implementation
├── cmd/                   # Go binaries
├── scripts/               # Operational scripts
├── tests/                 # NixOS/integration tests
│
├── architecture/          # Machine-readable architecture rules
├── docs/                  # Human-facing documentation
├── opencode/              # AI engineering context
├── secrets/               # SOPS-encrypted secrets
│
├── AGENTS.md
├── ENGINEERING.md
├── CONTRIBUTING.md
├── IVALi_FLOW.md
├── ARCHITECTURE.md
├── ARCHITECTURE_AUDIT.md
├── ARCHITECTURE_PROGRESS.md
└── README.md
```

The repository itself is the source of truth for the actual structure.

Documentation must not invent directories, modules, services, or capabilities that do not exist.

---

# NixOS Architecture

NixOS is the primary infrastructure abstraction.

The configuration is divided into domains such as:

```text
Host
 ├── Boot
 ├── Hardware
 ├── Networking
 ├── Security
 ├── SSH
 ├── Desktop
 ├── Developer
 ├── Services
 ├── Observability
 ├── Recovery
 ├── Automation
 └── Storage
```

Hosts should primarily **compose capabilities**.

They should not contain large amounts of domain implementation logic.

## Flakes

`flake.nix` defines:

* inputs
* NixOS configurations
* Home Manager integration
* development shells
* packages
* checks
* tests
* deployment-related outputs where applicable

Typical host evaluation:

```bash
nix build .#nixosConfigurations.prague.config.system.build.toplevel
```

Validation:

```bash
nix flake check
```

Formatting:

```bash
nix fmt
```

---

# KDE Desktop Architecture

KDE Plasma is treated as a **first-class infrastructure domain**, not simply a collection of GUI packages.

The desktop platform includes:

```text
KDE Plasma
├── KWin
├── Wayland
├── SDDM
├── XDG portals
├── PipeWire
├── WirePlumber
├── Bluetooth
├── NetworkManager integration
├── AMD GPU acceleration
├── Power management
├── External displays
├── Screen sharing
├── Camera / microphone
└── Application integration
```

The current desktop direction is a polished KDE Plasma environment with the **Garuda Mokka** visual design direction.

The desktop configuration should remain:

* declarative
* reproducible
* resource-conscious
* accessible remotely when required
* integrated with Linux security
* observable
* recoverable

Desktop changes should be tested at the appropriate levels.

For example:

```text
Nix evaluation
      ↓
Package availability
      ↓
Configuration evaluation
      ↓
Desktop/session test
      ↓
Runtime verification
      ↓
User-facing validation
```

Desktop infrastructure includes special attention to:

* PipeWire/WirePlumber
* microphone and speaker routing
* Bluetooth
* Wayland
* XDG portals
* screen sharing
* camera access
* external monitors
* suspend/resume
* power management
* GPU acceleration
* KDE application integration
* browser integration
* remote GUI access

---

# Linux and System Architecture

NixOS provides the declarative layer, but Linux behavior remains fundamental.

The system is therefore designed with explicit knowledge of:

* Linux processes
* systemd
* cgroups
* namespaces
* capabilities
* filesystems
* permissions
* sockets
* networking
* kernel parameters
* kernel modules
* device management
* udev
* journald
* bootloader behavior
* initrd
* memory pressure
* CPU scheduling
* power management

The engineering rule is:

> **Do not hide Linux behavior behind Nix abstractions when understanding the underlying Linux mechanism is necessary to diagnose or safely change the system.**

A NixOS change should therefore be validated from both perspectives:

```text
Nix declaration
      ↓
Generated configuration
      ↓
Linux/systemd behavior
      ↓
Runtime state
```

---

# Control Plane

The repository contains a Go-based control plane and CLI named:

```bash
ivali
```

The control plane provides operational capabilities including:

* status
* health
* diagnostics
* repository inspection
* architecture inspection
* dependency graphs
* verification
* deployment
* reconciliation
* rollback
* metrics
* dashboards
* documentation generation
* repository scanning
* API access

The Go architecture follows:

```text
CLI / API
   ↓
Application commands
   ↓
Domain orchestration
   ↓
Service interfaces
   ↓
Infrastructure adapters
   ↓
Linux / NixOS / external systems
```

Infrastructure implementations should not leak directly into unrelated domains.

Service contracts provide the abstraction boundary.

---

# GitOps and Deployment

GitLab is the authoritative source repository.

GitHub is used as a validation mirror where configured.

Deployment is performed by the GitOps control plane rather than treating CI as the deployment mechanism.

The intended lifecycle is:

```text
Change
  ↓
Feature branch
  ↓
TDD
  ↓
Local verification
  ↓
Ivali Flow
  ↓
Merge Request
  ↓
CI gates
  ↓
Merge
  ↓
GitOps reconciliation
  ↓
Nix evaluation/build
  ↓
NixOS generation
  ↓
Deployment
  ↓
Health verification
  ↓
Observe
  ↓
Rollback if unhealthy
```

Deployment is considered successful only when the **running system** passes its post-deployment health checks.

A successful build alone is not a successful deployment.

---

# Ivali Flow

All repository changes follow `IVALi_FLOW.md`.

The mandatory lifecycle is:

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
MERGE REQUEST
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

The AI engineering rules are intentionally strict.

AI agents must:

* inspect the repository before changing it
* read applicable architecture documentation
* follow `AGENTS.md`
* follow `IVALi_FLOW.md`
* write tests before implementation for new behavior
* reproduce bugs before fixing them
* never invent files or commands
* never claim tests passed without evidence
* never claim deployment succeeded without evidence
* preserve architecture boundaries
* avoid unnecessary rewrites
* avoid bypassing CI
* avoid weakening security to make a problem disappear

Git lifecycle operations are performed through the repository's approved Ivali Flow mechanisms rather than ad-hoc Git operations.

---

# Testing and Verification

Testing is layered.

## Nix

```bash
nix fmt
nix flake check
nix build .#nixosConfigurations.prague.config.system.build.toplevel
```

## Go

```bash
go test ./...
go test -race ./...
go vet ./...
go build ./...
```

## Shell

```bash
shellcheck scripts/*.sh
```

## Architecture

Architecture validation covers areas such as:

* forbidden imports
* dependency direction
* circular dependencies
* filesystem ownership
* duplicate ownership
* declared dependencies
* internal API boundaries
* service state ownership

## NixOS

Where appropriate:

* NixOS VM tests
* service tests
* security smoke tests
* observability tests
* Home Manager tests
* integration tests

## Verification philosophy

The preferred order is:

```text
Format
 ↓
Unit tests
 ↓
Architecture tests
 ↓
Static analysis
 ↓
Build/evaluation
 ↓
Integration tests
 ↓
Deployment
 ↓
Runtime health
 ↓
Operational observation
```

---

# Security

Security is implemented as multiple layers.

| Layer            | Controls                                   |
| ---------------- | ------------------------------------------ |
| Kernel           | Kernel hardening and restricted interfaces |
| Network          | nftables and explicit network policy       |
| Identity         | Unix users/groups and sudo policy          |
| SSH              | Hardened SSH and Tailscale access          |
| Overlay          | Tailscale zero-trust network               |
| Application      | Service sandboxing and least privilege     |
| Mandatory access | AppArmor where applicable                  |
| Abuse prevention | fail2ban where applicable                  |
| Secrets          | SOPS + age                                 |
| Monitoring       | Prometheus / security telemetry            |
| Detection        | Falco / security scanning                  |
| Recovery         | Rollback and generation recovery           |

Security changes should follow:

```text
Threat
  ↓
Control
  ↓
Verification
  ↓
Monitoring
  ↓
Recovery
```

Security must not depend on undocumented manual state.

---

# Networking and Tailscale

Tailscale is the primary trusted network overlay for private administration and service access.

The intended model is:

```text
Internet
   │
   X
   │
Public exposure
   │
   X
   │
Tailscale
   │
   ├── SSH
   ├── Administration
   ├── Control Plane
   ├── Monitoring
   ├── DNS services
   └── Remote access
```

The tailnet provides:

* private connectivity
* MagicDNS
* secure SSH access
* exit-node capability where configured
* remote administration
* service access
* monitoring access
* emergency access

Firewall rules must preserve a clear ownership model.

A network port should have one authoritative owner.

---

# Observability and SRE

The system follows SRE principles rather than treating monitoring as an afterthought.

The observability model covers:

```text
Metrics
Logs
Traces
Events
Health
SLOs
Alerts
Audit
Recovery
```

Primary components include:

* Prometheus
* Grafana
* Loki
* Grafana Alloy
* OpenTelemetry
* Alertmanager
* Falco
* NixOS/system exporters
* custom health endpoints
* `ivali` diagnostics

## Service observability

Every important service should answer:

1. Is it running?
2. Is it healthy?
3. What resources is it consuming?
4. What has it logged?
5. What dependencies does it have?
6. What happens if it fails?
7. How is it recovered?
8. How is its failure detected?

## SRE principles

The system emphasizes:

* reliability
* availability
* observability
* recoverability
* capacity awareness
* graceful degradation
* failure isolation
* automation
* operational simplicity
* measurable health

---

# Recovery and Self-Healing

Self-healing is bounded automation, not unrestricted autonomy.

The recovery hierarchy is:

```text
Service failure
     ↓
systemd recovery
     ↓
Health detection
     ↓
Operational remediation
     ↓
Deployment rollback
     ↓
Previous known-good generation
```

Recovery actions must be:

* deterministic
* observable
* bounded
* auditable
* reversible where possible

The system should avoid recovery loops and deployment thrashing through:

* locking
* cooldowns
* hysteresis
* health gates
* generation validation

Rollback is treated as a first-class operational capability.

---

# Secrets

Secrets are encrypted using:

```text
SOPS + age
```

Secrets must never be committed in plaintext.

Typical secret categories include:

* Tailscale credentials
* SMTP credentials
* GitLab credentials
* service credentials
* host-specific secrets
* application secrets

Runtime secret material should be exposed only to the authorized consumer.

The architecture follows:

```text
Encrypted secret
      ↓
SOPS / age
      ↓
Authorized runtime consumer
```

No alternate ad-hoc secret-management mechanism should be introduced without an explicit architectural decision.

---

# Home Manager

Home Manager provides the user-level configuration layer.

Typical responsibilities include:

* Zsh
* shell aliases
* terminal tooling
* Git configuration
* editor configuration
* Firefox
* fonts
* MIME defaults
* XDG configuration
* user packages
* desktop integration
* application preferences
* development tooling

The system-level and user-level boundaries are intentional:

```text
NixOS
  → Operating system
  → Services
  → Security
  → Hardware
  → Networking

Home Manager
  → User environment
  → Applications
  → Shell
  → User configuration
  → Desktop preferences
```

---

# AI Engineering

This repository is designed to be operated with AI-assisted engineering.

AI agents are expected to function as **senior infrastructure engineers**, not code generators.

The repository therefore provides dedicated AI context under:

```text
opencode/
```

and repository-level governance through:

```text
AGENTS.md
IVALi_FLOW.md
ENGINEERING.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
```

AI agents must understand four major engineering domains:

### NixOS

* Nix language
* flakes
* module system
* options
* overlays
* derivations
* NixOS evaluation
* Home Manager
* system generations
* reproducibility

### Linux

* systemd
* journald
* networking
* filesystems
* permissions
* processes
* cgroups
* kernel behavior
* hardware
* boot
* troubleshooting

### KDE

* Plasma
* KWin
* Wayland
* SDDM
* portals
* PipeWire
* WirePlumber
* KDE configuration
* desktop performance
* application integration

### SRE

* reliability
* monitoring
* alerting
* SLOs
* incident response
* capacity
* failure domains
* recovery
* rollback
* operational automation

AI work must preserve the repository's architecture and operational invariants.

---

# Development Workflow

Before modifying the system:

```bash
git status
```

Then inspect the relevant architecture and repository guidance.

Typical validation:

```bash
nix fmt
nix flake check
go test ./...
go vet ./...
go build ./...
shellcheck scripts/*.sh
```

For the primary host:

```bash
nix build .#nixosConfigurations.prague.config.system.build.toplevel
```

For repository-wide verification:

```bash
ivali verify
```

For diagnostics:

```bash
ivali doctor
```

For status:

```bash
ivali status
```

The exact command set should always be confirmed against the current repository implementation rather than assumed from historical documentation.

---

# Installation

The preferred installation path is the repository's maintained installer.

From a fresh NixOS environment:

```bash
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#curl \
  --command bash -c \
  'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
```

The installer is responsible for bootstrapping the repository and preparing the host configuration.

After installation:

```bash
ivali status
ivali doctor
tailscale status
```

Before performing destructive or hardware-sensitive operations, verify the generated configuration and recovery path.

---

# Daily Operations

## Repository

```bash
ivali status
ivali doctor
ivali verify
ivali metrics
ivali scan
```

## Nix

```bash
nix fmt
nix flake check
nix flake update
nix store gc
```

## System

```bash
systemctl --failed
journalctl -b
nixos-rebuild list-generations
```

## Networking

```bash
tailscale status
ip addr
ip route
resolvectl status
```

## Services

```bash
systemctl --type=service
systemctl --failed
```

The `ivali` CLI should be preferred for higher-level diagnostics where an equivalent command exists.

---

# Host Management

Hosts are represented as explicit infrastructure definitions.

Current hosts may include:

```text
prague
tuscany
testvm
```

Additional hosts should be introduced through the repository's host architecture rather than by copying an existing configuration and manually modifying it.

For a new host:

```text
Host definition
      ↓
Hardware configuration
      ↓
Capabilities
      ↓
Secrets
      ↓
Architecture validation
      ↓
Nix evaluation
      ↓
Build
      ↓
Deployment
      ↓
Health verification
```

The planned `oracle-edge` ARM64 infrastructure follows the same architectural principles while serving a different operational role: lightweight, hardened, always-on infrastructure for remote control-plane, monitoring, emergency access, backup, and supporting services.

---

# Documentation

The repository intentionally separates architectural truth from operational documentation.

| Document                   | Purpose                                   |
| -------------------------- | ----------------------------------------- |
| `README.md`                | Repository entry point                    |
| `AGENTS.md`                | AI agent operating rules                  |
| `IVALi_FLOW.md`            | Mandatory engineering/deployment workflow |
| `ENGINEERING.md`           | Engineering standards                     |
| `CONTRIBUTING.md`          | Contribution rules                        |
| `ARCHITECTURE.md`          | Intended architecture                     |
| `ARCHITECTURE_AUDIT.md`    | Current-state architecture conformance    |
| `ARCHITECTURE_PROGRESS.md` | Migration and implementation progress     |
| `docs/INFRASTRUCTURE.md`   | Detailed infrastructure reference         |
| `opencode/`                | AI-specific repository context            |
| `docs/`                    | Operational and subsystem documentation   |

### Documentation authority

When documentation conflicts with executable repository state:

```text
Current repository
        ↓
Executable tests
        ↓
Architecture manifests
        ↓
Architecture tooling
        ↓
Nix evaluation
        ↓
Go tests/build
        ↓
Runtime evidence
        ↓
Documentation
        ↓
Historical assumptions
```

Documentation should be corrected rather than used to justify behavior that no longer exists.

---

# Architecture Governance

Architecture is maintained through machine-readable definitions under:

```text
architecture/
```

These definitions describe concepts such as:

* domains
* dependencies
* ownership
* exceptions
* service boundaries

Architecture validation should detect:

* invalid domains
* forbidden dependencies
* dependency cycles
* filesystem ownership conflicts
* duplicate ownership
* undeclared dependencies
* internal API violations
* invalid exceptions
* service-state ownership violations

The goal is progressive enforcement:

```text
Implicit
   ↓
Documented
   ↓
Machine-readable
   ↓
Tested
   ↓
CI-enforced
   ↓
Self-protecting
```

An architecture exception must be explicit, justified, scoped, and reviewable.

---

# Operational Model

The infrastructure follows a layered control model:

```text
                    ┌───────────────────────┐
                    │       Human           │
                    │ Architecture / Policy │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │     Ivali Flow        │
                    │ Engineering Governance│
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │      GitLab           │
                    │   Source of Truth     │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │       CI Gates        │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │      GitOps           │
                    │    Reconciliation     │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │       NixOS           │
                    │      Generation        │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Health / Observability│
                    └───────────┬───────────┘
                                │
                         ┌──────┴──────┐
                         ▼             ▼
                       Healthy       Failed
                         │             │
                         ▼             ▼
                       Observe      Recover
                                       │
                                       ▼
                                    Rollback
```

This separation is intentional.

**Code acceptance, deployment, runtime health, and recovery are different concerns.**

---

# Design Goals

The long-term goal is not simply to have a highly configured laptop.

The goal is to build a **small, disciplined infrastructure platform** that demonstrates production engineering principles:

* declarative infrastructure
* reproducibility
* architecture governance
* automated testing
* secure networking
* least privilege
* observability
* SRE practices
* automated recovery
* controlled deployment
* explicit ownership
* AI-assisted engineering
* operational simplicity

The system should remain understandable even as it grows.

---

# Roadmap

Major areas of ongoing development include:

### Architecture

* continuous architecture auditing
* complete service-contract migration
* removal of legacy coupling
* stronger dependency enforcement
* configuration ownership consolidation
* filesystem ownership enforcement

### NixOS

* continued modularization
* reproducible host provisioning
* improved hardware abstraction
* stronger NixOS test coverage
* automated generation validation

### KDE

* polished KDE Plasma environment
* Garuda Mokka-inspired visual system
* Wayland-first configuration
* PipeWire/WirePlumber reliability
* display and suspend reliability
* remote GUI administration
* resource-conscious desktop operation

### SRE

* stronger SLO coverage
* improved health models
* richer incident diagnostics
* better recovery automation
* capacity monitoring
* deployment safety
* failure-domain isolation

### Control Plane

* richer `ivali` diagnostics
* architecture-aware operations
* deployment history
* health and recovery visualization
* operational API
* control-plane web UI
* mobile-friendly administration over Tailscale

### Infrastructure

* ARM64 `oracle-edge`
* hardened always-on control-plane infrastructure
* remote monitoring
* backup and recovery services
* emergency access
* encrypted backup
* resilient external watchdog capability

---

# Definition of Done

A change is not complete merely because the code compiles.

A production-quality change should satisfy the applicable requirements below:

```text
✓ Requirement understood
✓ Architecture understood
✓ Existing implementation inspected
✓ Failure reproduced where applicable
✓ Test written first where applicable
✓ RED demonstrated where applicable
✓ Implementation completed
✓ GREEN demonstrated
✓ Refactoring completed where useful
✓ Architecture tests pass
✓ Security implications reviewed
✓ Nix evaluation passes
✓ Go tests/build pass where applicable
✓ Shell validation passes where applicable
✓ CI passes
✓ Merge completed through Ivali Flow
✓ Deployment verified
✓ Runtime health verified
✓ Observability verified
✓ Recovery path verified
✓ Documentation updated
```

The exact gates depend on the change.

The principle does not:

> **A change is complete when the repository, generated system, and running system all agree that the change is correct.**

---

# License

MIT — see [`LICENSE`](LICENSE).

