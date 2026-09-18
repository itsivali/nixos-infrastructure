# Architecture

> **Authoritative architectural reference for the ivali NixOS infrastructure.**
>
> This document defines the repository's **normative architecture**: domain
> ownership, capability boundaries, dependency rules, host composition,
> trust boundaries, network topology, state ownership, configuration
> ownership, secret lifecycle, observability, reliability objectives,
> deployment, recovery, testing, architecture enforcement, and migration
> policy.
>
> The purpose of this document is to make the architecture understandable to
> humans and enforceable by machines.
>
> `ARCHITECTURE.md` defines **what the architecture permits and requires**.
> Machine-readable policy under `architecture/` defines the enforceable data
> model. Architecture tests, linters, CI, and the `ivali` verification workflow
> enforce those rules against the repository.
>
> The repository's current implementation may temporarily differ from the
> target architecture. Such differences must be explicitly classified and,
> where architecturally significant, tracked as exceptions or migration work.

---

# Table of Contents

1. [Document Status and Conventions](#1-document-status-and-conventions)
2. [Purpose](#2-purpose)
3. [Architecture Authority Model](#3-architecture-authority-model)
4. [Normative Language](#4-normative-language)
5. [Architectural Principles](#5-architectural-principles)
6. [System Context](#6-system-context)
7. [Architecture Layers](#7-architecture-layers)
8. [Domain Model](#8-domain-model)
9. [Capability Model](#9-capability-model)
10. [Host Composition](#10-host-composition)
11. [Domain Responsibilities](#11-domain-responsibilities)
12. [Domain Boundary Rules](#12-domain-boundary-rules)
13. [Dependency Architecture](#13-dependency-architecture)
14. [Trust and Threat Model](#14-trust-and-threat-model)
15. [Identity and Access Architecture](#15-identity-and-access-architecture)
16. [Network Architecture](#16-network-architecture)
17. [Prague Gateway Architecture](#17-prague-gateway-architecture)
18. [State Ownership](#18-state-ownership)
19. [Configuration Ownership](#19-configuration-ownership)
20. [Filesystem Ownership](#20-filesystem-ownership)
21. [Data Classification](#21-data-classification)
22. [Secret Architecture and Lifecycle](#22-secret-architecture-and-lifecycle)
23. [Process and systemd Architecture](#23-process-and-systemd-architecture)
24. [Service Contract Architecture](#24-service-contract-architecture)
25. [Observability Architecture](#25-observability-architecture)
26. [Reliability and Service Objectives](#26-reliability-and-service-objectives)
27. [Deployment and GitOps Architecture](#27-deployment-and-gitops-architecture)
28. [Supply-Chain and Provenance Architecture](#28-supply-chain-and-provenance-architecture)
29. [Recovery and Rollback Architecture](#29-recovery-and-rollback-architecture)
30. [Testing and Architecture Fitness](#30-testing-and-architecture-fitness)
31. [Architecture Enforcement](#31-architecture-enforcement)
32. [Architecture Exceptions](#32-architecture-exceptions)
33. [Architecture Decision Records](#33-architecture-decision-records)
34. [Schema and Versioning Policy](#34-schema-and-versioning-policy)
35. [Migration Strategy](#35-migration-strategy)
36. [Adding a New Domain](#36-adding-a-new-domain)
37. [Adding a New Capability](#37-adding-a-new-capability)
38. [Adding a New Service](#38-adding-a-new-service)
39. [AI Agent Architecture Contract](#39-ai-agent-architecture-contract)
40. [Architecture Review Checklist](#40-architecture-review-checklist)
41. [Definition of Architectural Done](#41-definition-of-architectural-done)
42. [Final Target Architecture](#42-final-target-architecture)
43. [Core Architectural Invariants](#43-core-architectural-invariants)
44. [Architecture Operating Loop](#44-architecture-operating-loop)

---

# 1. Document Status and Conventions

## 1.1 Status

This document is the normative architecture specification for the repository.

It describes:

* architectural policy;
* ownership;
* boundaries;
* capabilities;
* trust relationships;
* operational guarantees;
* target-state architecture.

It does **not** attempt to reproduce every implementation detail in Nix,
Go, shell, or CI configuration.

Implementation source code remains responsible for implementation detail.

---

## 1.2 Current state versus target state

The architecture distinguishes:

```text
CURRENT STATE
    what is implemented now

TARGET STATE
    what the architecture requires ultimately

MIGRATION STATE
    known work required to move current → target
```

A current-state deviation is not automatically an architecture violation.

It becomes an architecture violation when it is:

* forbidden by a normative rule;
* undocumented;
* outside an approved exception;
* or allowed to persist after its migration deadline.

---

# 2. Purpose

The ivali infrastructure is a:

> **domain-oriented, declarative, test-driven, GitOps-managed, security-conscious, observable, recoverable NixOS platform.**

The architecture exists to prevent the repository from becoming an uncontrolled
collection of:

* NixOS modules;
* Home Manager modules;
* shell scripts;
* Go packages;
* systemd units;
* services;
* CI jobs;
* security controls;
* network rules;
* automation;
* AI-generated modifications;

that happen to work together without explicit ownership.

The architecture MUST provide:

* clear ownership;
* explicit boundaries;
* controlled dependencies;
* predictable composition;
* reproducibility;
* testability;
* observability;
* least privilege;
* controlled state;
* secure secret handling;
* operational clarity;
* reliability;
* recoverability;
* safe AI-assisted engineering.

The architecture is not documentation-only.

> **Any architectural rule that can reasonably be expressed as a schema,
> assertion, test, linter rule, or CI gate SHOULD be enforced mechanically.**

---

# 3. Architecture Authority Model

Three concepts must be kept distinct.

## 3.1 Current reality

The repository and runtime environment establish:

> **what currently exists.**

This includes:

* files;
* modules;
* imports;
* hosts;
* services;
* package declarations;
* systemd units;
* runtime state;
* deployed generations.

Current reality MUST NOT automatically override architectural policy.

---

## 3.2 Architectural policy

Architectural policy establishes:

> **what is permitted and required.**

The normative sources are:

```text
ARCHITECTURE.md
        +
architecture/*.yaml
        +
approved ADRs
        +
explicit exceptions
```

---

## 3.3 Executable enforcement

Executable enforcement establishes:

> **whether the repository currently complies with policy.**

Examples:

```text
architecture tests
architecture linter
Nix assertions
Go tests
integration tests
security tests
CI gates
deployment health checks
```

---

## 3.4 Authority relationship

The model is:

```text
CURRENT REALITY
      │
      │ inspection
      ▼
ARCHITECTURAL POLICY
      │
      ▼
EXECUTABLE ENFORCEMENT
      │
      ▼
COMPLIANCE RESULT
```

Therefore:

> The repository is authoritative for discovering current reality, while
> architectural policy is authoritative for determining whether that reality
> is acceptable.

---

# 4. Normative Language

The following terms are normative.

### MUST

Absolute requirement.

### MUST NOT

Prohibited behavior.

### SHOULD

Strong recommendation that requires justification to deviate from.

### SHOULD NOT

Strongly discouraged behavior that requires justification to retain.

### MAY

Permitted but optional.

### CURRENTLY

Describes the present implementation, not necessarily the desired architecture.

### TARGET

Describes intended future state.

### EXAMPLE

Illustrative only; not itself authoritative.

---

# 5. Architectural Principles

## 5.1 Single ownership

Every significant capability MUST have one authoritative owner.

```text
ONE CAPABILITY
      ↓
ONE OWNER
      ↓
ONE SOURCE OF TRUTH
```

Multiple consumers are allowed.

Multiple competing implementations are not.

---

## 5.2 Explicit boundaries

Domains MUST communicate through explicit boundaries.

A domain MUST NOT directly consume another domain's:

* private implementation;
* private filesystem state;
* secrets;
* database;
* locks;
* mutable caches;
* generated internal files;

unless the access is explicitly permitted.

---

## 5.3 Explicit dependencies

Dependencies MUST be visible and reviewable.

No domain should depend on another merely because an import happens to work.

---

## 5.4 Declarative infrastructure

NixOS and Home Manager configuration are declarative.

Configuration MUST NOT be silently duplicated in:

* shell scripts;
* Go code;
* generated files;
* undocumented systemd overrides;
* manual operator procedures.

Imperative code MAY exist for:

* operational actions;
* migration;
* runtime orchestration;
* external API integration;
* recovery tasks;

but it MUST NOT become a competing configuration authority.

---

## 5.5 Verification-first development

Behavior-changing work MUST use verification-driven development.

Preferred flow:

```text
DEFINE INVARIANT
      ↓
WRITE TEST / CHECK
      ↓
RUN TEST
      ↓
IMPLEMENT
      ↓
VERIFY
      ↓
REFACTOR
      ↓
INTEGRATE
```

Literal RED/GREEN TDD SHOULD be used where a meaningful executable test exists.

Where a literal failing test is not meaningful, the change MUST have another
explicit verification mechanism such as:

* static validation;
* schema validation;
* architecture test;
* Nix assertion;
* integration test;
* generated artifact comparison.

---

## 5.6 Reproducibility

Equivalent declared inputs SHOULD produce equivalent intended system behavior.

The system MUST minimize dependence on:

* mutable host state;
* undeclared filesystem data;
* manual setup;
* user-specific hidden state;
* undocumented network assumptions.

---

## 5.7 Least privilege

Every identity, process, service, host, and network path MUST receive only the
authority it requires.

---

## 5.8 Secure defaults

Dangerous capabilities SHOULD default to disabled unless a host explicitly
requires them.

Examples include:

* exit-node capability;
* public ingress;
* privileged services;
* unrestricted command execution.

An intentional exception exists for capabilities that are **architectural
invariants of a specific host**, such as Prague's exit-node role.

---

## 5.9 Observability

A capability is incomplete if operators cannot determine:

* whether it is working;
* what failed;
* why it failed;
* what changed;
* how to recover it.

---

## 5.10 Recovery is part of design

Backup, rollback, health validation, and recovery are architecture concerns.

They are not optional afterthoughts.

---

# 6. System Context

The system contains:

```text
                         ┌─────────────────────┐
                         │       OPERATOR      │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │   IVALI CONTROL     │
                         │      PLANE / UI     │
                         └──────────┬──────────┘
                                    │
                                    ▼
                    ┌────────────────────────────────┐
                    │     SERVICE / DOMAIN LAYER     │
                    └───────────────┬────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          ▼                         ▼                         ▼
    ┌───────────┐            ┌──────────────┐          ┌──────────────┐
    │ GitOps /  │            │ Observability│          │ Security /   │
    │ Platform  │            │ / Health     │          │ Networking   │
    └─────┬─────┘            └──────┬───────┘          └──────┬───────┘
          │                         │                         │
          └─────────────────────────┼─────────────────────────┘
                                    ▼
                         ┌─────────────────────┐
                         │    NixOS SYSTEM     │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ HOST / HARDWARE     │
                         │ Prague / Tuscany /… │
                         └─────────────────────┘
```

The control plane orchestrates capabilities.

It does not become the owner of every subsystem.

---

# 7. Architecture Layers

The architecture consists of the following logical layers.

## Layer 1 — Governance

```text
architecture/
ARCHITECTURE.md
ADRs
exceptions
CI policy
```

---

## Layer 2 — Source and Delivery

```text
Git
CI/CD
review
artifacts
deployment provenance
```

---

## Layer 3 — Composition

```text
flake
hosts
profiles
domains
capabilities
Home Manager
NixOS modules
```

---

## Layer 4 — Platform

```text
boot
hardware
system
storage
networking
security
desktop
services
```

---

## Layer 5 — Operational Control

```text
GitOps
health
backup
recovery
automation
control plane
```

---

## Layer 6 — Runtime Infrastructure

```text
systemd
filesystem
kernel
network
applications
```

---

# 8. Domain Model

The repository is organized into explicit architectural domains.

The exact directory mapping is authoritative from the machine-readable domain
manifest.

Core domains include:

| Domain           | Responsibility                                  |
| ---------------- | ----------------------------------------------- |
| `architecture`   | Architectural policy and validation             |
| `hosts`          | Host composition and host-specific declarations |
| `boot`           | Bootloader, kernel, initrd, early boot          |
| `hardware`       | Hardware-specific configuration                 |
| `system`         | Base operating-system policy                    |
| `storage`        | Filesystems, mounts, storage                    |
| `networking`     | Interfaces, DNS, routing, network integration   |
| `security`       | Hardening, authorization, firewall, isolation   |
| `ssh`            | SSH server/client and remote access policy      |
| `desktop`        | GNOME/session/display integration               |
| `home`           | Home Manager/user environment                   |
| `developer`      | Development environment                         |
| `packages`       | Package composition                             |
| `services`       | Application/system services                     |
| `observability`  | Metrics, logs, health, alerting                 |
| `recovery`       | Backup, rollback, disaster recovery             |
| `automation`     | Scheduled and automated operations              |
| `virtualization` | VM/container infrastructure                     |
| `internal`       | Go control-plane implementation                 |
| `ci`             | Continuous integration and delivery             |
| `scripts`        | Operational scripts                             |

The list is descriptive unless represented normatively in the domain manifest.

---

# 9. Capability Model

Capabilities are the architectural unit of host composition.

A capability represents:

> **A meaningful operational behavior that a host may provide.**

Examples:

```text
desktop
gnome
tailscale
exit-node
remote-admin
remote-desktop
gitops
monitoring
backup
public-ingress
developer-workstation
edge-gateway
```

Capabilities SHOULD be represented in machine-readable policy.

Example:

```yaml
capabilities:
  tailscale:
    owner: networking

  exit-node:
    owner: networking
    security_boundary: gateway

  gitops:
    owner: automation
    security_boundary: deployment
```

---

## 9.1 Capability rules

A capability MUST have:

* owner;
* purpose;
* dependencies;
* security boundary;
* observability requirements;
* activation rules;
* test strategy.

---

## 9.2 Host capability declaration

Hosts SHOULD declare capabilities explicitly.

Conceptually:

```yaml
hosts:
  prague:
    capabilities:
      - laptop
      - desktop
      - tailscale
      - exit-node
      - remote-admin
      - remote-desktop
      - gitops
```

Other hosts must not inherit these capabilities accidentally.

---

# 10. Host Composition

Hosts are composition roots.

```text
HOST
  │
  ├── profile selection
  ├── capability selection
  ├── hardware declaration
  ├── host-specific configuration
  └── domain composition
```

A host MUST NOT implement reusable domain logic.

### Rule

```text
HOST = COMPOSITION

HOST ≠ DOMAIN IMPLEMENTATION
```

---

## 10.1 Host isolation

Every physical host MUST have a host-appropriate hardware declaration.

A physical host MUST NOT silently inherit another physical host's:

* disk UUID;
* filesystem layout;
* swap device;
* GPU configuration;
* firmware configuration;
* device-specific hardware settings.

Fallbacks that point to actual physical hardware MUST NOT be used as generic
host defaults.

---

# 11. Domain Responsibilities

## 11.1 `hosts`

Owns:

* composition;
* host-specific values;
* capability selection;
* host-level assertions;
* hardware linkage.

Does not own reusable implementation.

---

## 11.2 `boot`

Owns:

* bootloader;
* kernel;
* initrd;
* early-boot security;
* boot-time recovery dependencies.

Does not own applications.

---

## 11.3 `hardware`

Owns:

* GPU;
* audio hardware;
* Bluetooth hardware;
* device-specific drivers;
* machine-specific hardware quirks.

Hardware-specific behavior SHOULD remain isolated from generic platform policy.

---

## 11.4 `networking`

Owns:

* network interfaces;
* NetworkManager;
* DNS integration;
* routing;
* Tailscale;
* forwarding;
* network policy integration.

Application-specific logic does not belong here.

---

## 11.5 `security`

Owns:

* hardening;
* authentication policy;
* authorization;
* firewall;
* sandboxing;
* AppArmor;
* security services;
* security-related system policy.

---

## 11.6 `desktop`

Owns:

* GNOME/session;
* display manager;
* portals;
* graphical integration;
* desktop-level services.

Desktop policy MUST remain separable from headless server behavior.

---

## 11.7 `observability`

Owns:

* telemetry;
* metrics;
* logs;
* dashboards;
* health aggregation;
* alerts.

Observability observes other domains.

It does not become their state owner.

---

## 11.8 `recovery`

Owns:

* backup;
* snapshot;
* rollback;
* disaster recovery;
* recovery verification.

Recovery dependencies SHOULD be minimized to avoid circular failure.

---

# 12. Domain Boundary Rules

## Rule 1 — No private-state access

A domain MUST NOT directly consume another domain's private state.

---

## Rule 2 — No duplicate ownership

A capability MUST NOT have competing implementations.

---

## Rule 3 — No configuration shadowing

Configuration MUST have one authoritative owner.

---

## Rule 4 — No hidden cross-domain mutation

A domain MUST NOT silently mutate another domain's state.

---

## Rule 5 — No circular dependency

The domain dependency graph SHOULD remain acyclic.

A cycle requires an explicit exception.

---

## Rule 6 — Host boundaries are hard boundaries

Generic domains MUST NOT depend on an individual host.

---

# 13. Dependency Architecture

## 13.1 Nix dependency direction

The preferred direction is:

```text
flake
  ↓
host
  ↓
profile / capability
  ↓
domain module
  ↓
platform implementation
```

Hosts may depend on domains.

Domains MUST NOT depend on named hosts.

---

## 13.2 Runtime dependency direction

```text
UI / CLI
   ↓
application layer
   ↓
domain orchestration
   ↓
service contract
   ↓
infrastructure adapter
   ↓
system / NixOS / systemd / external backend
```

---

## 13.3 Forbidden dependencies

Examples:

```text
UI → arbitrary shell
UI → private filesystem state
GitOps → backup repository internals
Health → deployment private state
Service A → Service B private database
Domain A → Domain B undocumented implementation
```

---

# 14. Trust and Threat Model

The architecture MUST explicitly distinguish threats from ordinary operational
failures.

## 14.1 Threat actors

The system considers at least these threat classes:

```text
T1  compromised user process
T2  malicious or compromised CI job
T3  compromised developer credential
T4  compromised Git credential
T5  malicious repository change
T6  malicious or compromised Tailscale device
T7  compromised service/API
T8  compromised dependency / supply chain
T9  stolen laptop
T10 stolen phone
T11 compromised recovery or backup path
T12 accidental administrator error
```

Not all threats have equal likelihood or impact.

Risk assessment should be evidence-based.

---

## 14.2 Critical assets

Assets include:

```text
A1  root/system control
A2  SSH access
A3  Tailscale node identity
A4  exit-node capability
A5  SOPS/age decryption keys
A6  Git credentials
A7  CI credentials
A8  deployment authority
A9  backups
A10 user data
A11 infrastructure source
A12 observability/control-plane access
```

---

## 14.3 Trust boundaries

Major trust boundaries include:

```text
developer → Git
Git → CI
CI → artifact
artifact → deployment
deployment → root activation
Tailscale client → infrastructure
network → host
service → filesystem
service → secrets
control plane → system services
```

Each boundary MUST have explicit authentication, authorization, and trust
assumptions.

---

# 15. Identity and Access Architecture

Identity is modeled independently of capability.

Conceptually:

```text
HUMAN IDENTITY
     ↓
DEVICE IDENTITY
     ↓
NETWORK IDENTITY
     ↓
SERVICE IDENTITY
     ↓
PRIVILEGE
```

Access MUST be granted to the narrowest identity capable of fulfilling the
requirement.

---

## 15.1 Tailscale identity

Tailscale provides an infrastructure network identity boundary.

The tailnet policy is an external policy artifact and MUST be treated as part
of the network security architecture.

The current known-working ACL is the operational baseline until a validated
migration is approved.

The architecture MUST NOT assume that ACL migration to newer policy syntax is
safe merely because the syntax is newer.

---

# 16. Network Architecture

The network is divided into logical planes.

```text
                NETWORK
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
 Management      Egress       LAN
    Plane         Plane      Services
       │           │           │
       ▼           ▼           ▼
  SSH / RDP     Exit Node    LocalSend
  Tailscale      Internet
```

---

## 16.1 Management plane

Contains:

* SSH;
* GNOME Remote Desktop;
* administrative APIs;
* maintenance access.

Management access SHOULD be protected by Tailscale wherever practical.

---

## 16.2 Egress plane

Controls:

* Internet access;
* forwarding;
* NAT;
* exit-node behavior.

---

## 16.3 LAN-service plane

Contains LAN-oriented applications such as:

```text
LocalSend
```

LAN services MUST NOT automatically become tailnet or WAN services.

---

## 16.4 Firewall ownership

Firewall policy belongs to the networking/security architecture.

Individual applications MAY declare:

```text
required port
required protocol
required interface scope
```

but MUST NOT create competing firewall policy authorities.

---

# 17. Prague Gateway Architecture

Prague has a special architectural role.

## 17.1 Prague capabilities

Prague intentionally provides:

```text
laptop
desktop
Tailscale
exit-node
remote administration
remote desktop
GitOps/control plane
```

---

## 17.2 Permanent Tailscale invariant

For Prague:

```text
Tailscale MUST be enabled.
Tailscale MUST remain operational.
Prague MUST advertise exit-node capability.
Prague MUST support approved exit-node client traffic.
```

This is not considered an unsafe accidental default.

It is a deliberate host-specific capability.

---

## 17.3 Prague gateway path

The desired path is:

```text
Phone
  │
  │ Tailscale
  ▼
Prague
  │
  │ forwarding + NAT
  ▼
Internet
```

---

## 17.4 Gateway dependencies

Prague's exit-node capability depends on:

```text
Tailscale
IP forwarding
IPv4 routing
IPv6 routing where required
NAT
firewall forwarding
working uplink
network recovery
```

These dependencies MUST be treated as one operational capability.

---

## 17.5 Gateway health

Gateway health SHOULD verify:

```text
tailscaled active
tailscale interface present
tailnet connectivity
exit-node capability
forwarding state
NAT
firewall forwarding
uplink reachability
DNS
```

---

## 17.6 Exit-node policy

The current working tailnet ACL remains authoritative unless a deliberate
policy migration is performed.

Do not introduce `grants`/`via` merely for stylistic modernization.

A policy migration MUST include:

* syntax verification;
* policy validation;
* client testing;
* rollback;
* explicit reason.

---

# 18. State Ownership

Every persistent state resource MUST have one owner.

Examples:

| State                    | Owner                     |
| ------------------------ | ------------------------- |
| Host configuration       | `hosts` / Nix composition |
| User environment         | Home Manager              |
| GitOps state             | GitOps domain             |
| Deployment state         | Deployment/GitOps domain  |
| Backup metadata          | Recovery                  |
| Metrics state            | Observability             |
| Health cache             | Health/observability      |
| Tailscale identity state | Networking                |
| SSH host identity        | SSH                       |
| Application data         | Owning service            |

Consumers SHOULD access state through contracts rather than direct filesystem
access.

---

# 19. Configuration Ownership

Every configuration value MUST have:

```text
Owner
Source of truth
Consumers
Runtime representation
Override policy
```

Examples include:

```text
ports
paths
service endpoints
timeouts
Tailscale settings
firewall policy
desktop preferences
package selection
```

A configuration value MUST NOT silently exist in several independent systems.

---

# 20. Filesystem Ownership

Filesystem paths are architectural resources.

Each persistent path SHOULD declare:

```text
owner
purpose
persistence class
security classification
backup policy
consumers
```

Example:

```text
/var/lib/tailscale
    owner: networking
    class: identity-state

/var/lib/gitops
    owner: gitops
    class: operational-state

/run/deploy.lock
    owner: deployment
    class: synchronization-state
```

Direct cross-domain access requires an explicit rule.

---

# 21. Data Classification

All important system data MUST have a classification.

## 21.1 PUBLIC

Safe for public disclosure.

Examples:

* public documentation;
* public source code;
* public architecture diagrams.

---

## 21.2 INTERNAL

Not intended for public disclosure but not inherently secret.

Examples:

* internal service metadata;
* operational topology;
* non-sensitive metrics.

---

## 21.3 SENSITIVE

Disclosure could materially aid misuse or expose private information.

Examples:

* detailed internal network metadata;
* operational logs containing private information;
* system inventories.

---

## 21.4 SECRET

Material that MUST NOT be committed or exposed.

Examples:

* passwords;
* tokens;
* API keys;
* private credentials;
* age keys.

---

## 21.5 CRITICAL SECRET

Secrets whose compromise can result in infrastructure-wide compromise.

Examples:

* root/deployment signing material;
* master recovery credentials;
* unrestricted infrastructure decryption keys.

Critical secrets require stronger:

* access control;
* backup protection;
* rotation procedures;
* compromise procedures.

---

## 21.6 Data handling rules

Classification determines:

```text
storage
encryption
logging
backup
transport
retention
access
destruction
```

A higher classification MUST NOT be handled using a lower-class control without
an explicit exception.

---

# 22. Secret Architecture and Lifecycle

Secrets MUST follow a lifecycle:

```text
CREATE
  ↓
STORE
  ↓
DISTRIBUTE
  ↓
USE
  ↓
ROTATE
  ↓
REVOKE
  ↓
DESTROY
```

---

## 22.1 Secret source

Repository secrets SHOULD use:

```text
SOPS
+
age
```

or an explicitly approved equivalent.

---

## 22.2 Secret scope

Secrets SHOULD be separated by:

```text
host
service
environment
purpose
trust boundary
```

A service MUST receive only the secrets it requires.

---

## 22.3 Secret rotation

Every important secret SHOULD have:

```text
owner
rotation method
rotation frequency or trigger
revocation method
recovery method
compromise response
```

---

## 22.4 Secret recovery

Recovery keys MUST be protected independently enough that loss of the normal
host path does not automatically destroy recovery capability.

---

## 22.5 Forbidden secret behavior

Secrets MUST NOT appear in:

* Git;
* architecture manifests;
* CI logs;
* command output;
* application logs;
* debug dumps;
* system status output;
* screenshots;
* generated documentation.

---

# 23. Process and systemd Architecture

Every long-running process MUST have an identified owner.

The owner is responsible for:

* service definition;
* startup;
* dependencies;
* restart policy;
* resource limits;
* privilege;
* filesystem access;
* network access;
* logging;
* health;
* shutdown.

---

## 23.1 Systemd hardening

Services SHOULD use appropriate controls such as:

```text
User
Group
DynamicUser
NoNewPrivileges
ProtectSystem
ProtectHome
PrivateTmp
PrivateDevices
ProtectKernelTunables
ProtectKernelModules
ProtectControlGroups
RestrictAddressFamilies
RestrictNamespaces
RestrictSUIDSGID
CapabilityBoundingSet
SystemCallFilter
ReadWritePaths
InaccessiblePaths
```

Hardening MUST be verified against actual service requirements.

Security controls MUST NOT be disabled merely because an implementation has
not yet been correctly isolated.

---

# 24. Service Contract Architecture

Runtime components SHOULD communicate through explicit service contracts.

The architecture defines contract semantics.

The implementation source defines the exact language-level interface.

---

## 24.1 Notification service

### Responsibility

Provide centralized operational notification.

### Semantics

Consumers can:

* send alerts;
* send deployment outcomes;
* send health events.

Consumers MUST NOT silently create competing notification mechanisms.

---

## 24.2 Backup service

### Responsibility

Own backup operations.

### Semantics

Consumers can:

* trigger backup;
* query status;
* enumerate snapshots;
* query last successful run.

Consumers MUST NOT directly manipulate backup-repository internals.

---

## 24.3 Metrics provider

### Responsibility

Provide metrics and service-health information.

### Semantics

Consumers query observations.

Consumers MUST NOT become owners of the telemetry backend.

---

## 24.4 Health checker

### Responsibility

Provide normalized system-health information.

It SHOULD cover:

```text
system
services
network
storage
security-critical dependencies
gateway state
```

---

## 24.5 Platform service

### Responsibility

Provide high-level platform operations.

Examples:

```text
health
status
doctor
rebuild
rollback
```

Platform orchestration MUST remain bounded.

It MUST NOT become a miscellaneous root-command execution interface.

---

# 25. Observability Architecture

Observability has four major functions:

```text
METRICS
LOGS
HEALTH
ALERTING
```

---

## 25.1 Metrics

Metrics SHOULD cover:

* service health;
* resource usage;
* deployment state;
* gateway state;
* backup freshness;
* critical error counters.

---

## 25.2 Logs

Logs SHOULD provide enough information to diagnose:

* failure cause;
* sequence of events;
* operator action;
* recovery outcome.

Logs MUST respect data classification.

Secrets MUST never be logged.

---

## 25.3 Health

A health state MUST distinguish at least:

```text
HEALTHY
DEGRADED
FAILED
UNKNOWN
```

---

## 25.4 Alerts

Alerts MUST correspond to an actionable condition.

Avoid alerting merely because a metric changed.

---

# 26. Reliability and Service Objectives

Reliability MUST be expressed through explicit objectives where practical.

The architecture recognizes:

```text
SLO
RPO
RTO
```

---

## 26.1 SLO

A Service Level Objective defines expected service behavior.

Potential examples:

```text
Tailscale gateway availability
GitOps reconciliation success rate
backup freshness
remote-management availability
```

Exact numeric targets belong in the operational policy or service-specific
documentation rather than being invented here.

---

## 26.2 RPO

Recovery Point Objective defines the maximum acceptable data loss window.

Each stateful service SHOULD define one where meaningful.

---

## 26.3 RTO

Recovery Time Objective defines the desired restoration window after failure.

Each critical capability SHOULD define one.

---

## 26.4 Reliability rule

A capability without an understood failure mode and recovery objective is
operationally incomplete.

---

# 27. Deployment and GitOps Architecture

The desired deployment chain is:

```text
Developer
   ↓
Feature branch
   ↓
Tests
   ↓
Merge Request
   ↓
CI gates
   ↓
Approved merge
   ↓
Artifact / generation
   ↓
Deployment controller
   ↓
Activation
   ↓
Health gate
   ├── PASS → accepted
   └── FAIL → rollback
```

---

## 27.1 GitOps responsibilities

GitOps owns:

* desired configuration state;
* reconciliation;
* deployment intent;
* deployment status.

It does not own:

* backup internals;
* monitoring backend internals;
* application data.

---

## 27.2 Deployment authority

Deployment MUST have a clear privilege boundary.

Preferred model:

```text
unprivileged reconciler
        ↓
validated deployment request
        ↓
narrow privileged activation mechanism
        ↓
root
```

Avoid turning the reconciler into a general-purpose root shell.

---

## 27.3 Deployment lock

Concurrent deployment operations MUST be serialized.

A single authoritative deployment lock MUST cover:

* automatic deployment;
* manual deployment;
* rollback;
* relevant recovery actions.

---

## 27.4 Exit codes

Deployment and reconciliation processes MUST use meaningful exit semantics.

```text
0 = success
non-zero = failure
```

Failure exit codes MUST NOT be intentionally treated as successful by systemd
merely to suppress operational visibility.

---

# 28. Supply-Chain and Provenance Architecture

The infrastructure MUST maintain a traceable relationship between source and
deployment where practical.

Desired chain:

```text
Commit SHA
   ↓
Reviewed change
   ↓
CI result
   ↓
flake.lock / inputs
   ↓
Nix derivation
   ↓
Build artifact
   ↓
artifact provenance/signature
   ↓
deployment
   ↓
host generation
```

---

## 28.1 CI trust

CI execution MUST NOT automatically receive broader authority than necessary.

A build runner SHOULD:

* build;
* test;
* scan;
* publish artifacts;

but SHOULD NOT automatically become a trusted infrastructure administrator.

---

## 28.2 Dependency trust

External dependencies MUST be:

* pinned where practical;
* reviewable;
* updated deliberately;
* attributable.

Lockfile changes SHOULD receive heightened review.

---

## 28.3 Binary cache trust

Binary caches MUST have:

* explicit trust configuration;
* signing keys;
* ownership;
* availability policy;
* recovery behavior.

A binary cache is part of the supply chain, not merely a performance feature.

---

# 29. Recovery and Rollback Architecture

Recovery has three layers.

```text
1. Runtime recovery
2. Generation rollback
3. Disaster recovery
```

---

## 29.1 Runtime recovery

Examples:

```text
service restart
network recovery
automatic retry
health-triggered restart
```

---

## 29.2 Generation rollback

A broken deployment MUST be capable of returning to a known-good NixOS
generation where practical.

---

## 29.3 Boot health

A new generation SHOULD become "known good" only after:

```text
boot
   ↓
critical initialization
   ↓
network
   ↓
management path
   ↓
critical services
   ↓
health validation
   ↓
BOOT_COMPLETE
```

A generation that fails before late boot targets MUST still be covered by the
recovery strategy.

---

## 29.4 Recovery tests

Recovery SHOULD be tested against representative failures:

```text
broken network
broken SSH
broken service
failed activation
failed health check
bad generation
reboot during deployment
control-plane failure
```

---

# 30. Testing and Architecture Fitness

Testing MUST exist at multiple levels.

---

## 30.1 Unit tests

Verify individual code behavior.

---

## 30.2 Module/evaluation tests

Verify:

* options;
* assertions;
* evaluation;
* generated configuration.

---

## 30.3 Architecture tests

Verify:

* domains;
* dependencies;
* ownership;
* exceptions;
* capability rules;
* filesystem ownership;
* configuration ownership.

---

## 30.4 Integration tests

Verify cross-domain behavior.

---

## 30.5 End-to-end tests

Verify meaningful workflows.

Examples:

```text
phone
 → Tailscale
 → Prague
 → SSH

phone
 → Tailscale
 → Prague exit node
 → Internet

LAN
 → LocalSend
 → file transfer

Git change
 → CI
 → deployment
 → health
 → accepted/rollback
```

---

## 30.6 Negative testing

Security and architecture tests MUST test forbidden behavior as well as
allowed behavior.

Examples:

```text
unauthorized user denied
unauthorized device denied
forbidden port denied
privileged escalation denied
secret access denied
cross-domain filesystem access denied
invalid deployment denied
```

---

# 31. Architecture Enforcement

Machine-readable policy lives under:

```text
architecture/
```

The exact file inventory is repository-authoritative.

The expected conceptual model includes:

```text
domains.yaml
capabilities.yaml
dependencies.yaml
ownership.yaml
security.yaml
network.yaml
state.yaml
exceptions.yaml
schemas/
```

Individual files MAY be consolidated if the repository's implementation
provides equivalent coverage.

---

## 31.1 Domain enforcement

The validator SHOULD detect:

* undeclared domains;
* stale domains;
* paths belonging to multiple domains;
* missing owners.

---

## 31.2 Dependency enforcement

The validator SHOULD detect:

* forbidden dependencies;
* undeclared dependencies;
* cycles;
* host-to-domain violations;
* direct private-state access where statically detectable.

---

## 31.3 Ownership enforcement

The validator SHOULD detect:

* duplicate configuration ownership;
* duplicate port ownership;
* duplicate filesystem ownership;
* duplicate service ownership;
* conflicting capability definitions.

---

## 31.4 Exception enforcement

The validator MUST detect:

* missing owner;
* missing review date;
* expired exception;
* malformed exception;
* inactive exception still being relied upon.

---

## 31.5 CI enforcement

Architecture violations MUST fail CI unless explicitly permitted by an active
exception.

---

# 32. Architecture Exceptions

Exceptions exist to document legitimate deviations.

They are not loopholes.

Each exception MUST include:

```yaml
id:
source:
target:
reason:
owner:
created:
review:
status:
removal_plan:
```

---

## 32.1 Exception lifecycle

```text
PROPOSED
   ↓
REVIEWED
   ↓
ACTIVE
   ↓
REMOVED
```

or:

```text
ACTIVE
   ↓
REVIEW
   ↓
EXTENDED / REMOVED
```

---

## 32.2 Expired exceptions

An expired exception MUST fail architecture verification unless explicitly
renewed.

---

# 33. Architecture Decision Records

Architecture decisions explain **why** the architecture looks the way it does.

ADRs SHOULD live under:

```text
docs/adr/
```

Suggested examples:

```text
ADR-0001-domain-oriented-module-architecture.md
ADR-0002-prague-as-permanent-tailscale-exit-node.md
ADR-0003-edge-native-microsoft-365-pwa-runtime.md
ADR-0004-gitops-privileged-activation-boundary.md
ADR-0005-sops-age-secret-model.md
ADR-0006-host-capability-composition.md
```

---

## 33.1 ADR structure

Each ADR SHOULD contain:

```text
Status
Date
Context
Decision
Alternatives considered
Consequences
Security implications
Operational implications
Migration implications
```

---

## 33.2 Relationship to ARCHITECTURE.md

`ARCHITECTURE.md` describes:

> **what the current architecture is.**

ADRs describe:

> **why important architectural decisions were made.**

ADRs MUST NOT become a second conflicting architecture specification.

---

# 34. Schema and Versioning Policy

Machine-readable architecture MUST be versioned.

At minimum maintain:

```yaml
architecture_version:
schema_version:
```

Example:

```yaml
architecture_version: 2
schema_version: 1
```

---

## 34.1 Versioning rules

Breaking architectural schema changes MUST:

1. update schema version;
2. update validators;
3. migrate manifests;
4. update affected tests;
5. document migration;
6. update relevant ADRs.

---

## 34.2 Backward compatibility

A schema migration SHOULD have a clearly defined transition period where
practical.

Agents MUST NOT silently change schema semantics.

---

# 35. Migration Strategy

Architectural migration MUST be incremental.

---

## Phase 1 — Discover

Inventory:

```text
domains
capabilities
dependencies
state
configuration
services
trust boundaries
```

---

## Phase 2 — Define

Establish:

```text
owner
contract
security boundary
test strategy
migration path
```

---

## Phase 3 — Verify

Write architecture or behavior checks before migration where practical.

---

## Phase 4 — Migrate

Move consumers from old implementation to approved ownership boundary.

---

## Phase 5 — Remove

After consumers have migrated:

* remove duplicate implementation;
* remove obsolete configuration;
* remove old tests;
* update architecture manifests.

---

## Phase 6 — Enforce

Add permanent architecture rules so the old pattern cannot easily return.

---

# 36. Adding a New Domain

A new domain MUST NOT be created merely because a new folder seems convenient.

Before adding one, determine:

1. Does an existing domain already own this capability?
2. Is there genuinely independent state?
3. Is there a new trust boundary?
4. Is there a new lifecycle?
5. Are there distinct dependencies?
6. Does a distinct service contract make sense?
7. Does the domain warrant independent observability?
8. Does it require independent recovery?

If not, extend the existing domain.

---

# 37. Adding a New Capability

A capability MUST define:

```text
name
purpose
owner
security boundary
dependencies
host eligibility
configuration
state
network exposure
observability
testing
recovery
```

Example:

```yaml
capability:
  name: exit-node
  owner: networking
  security_boundary: gateway
  dependencies:
    - tailscale
    - forwarding
    - firewall
    - nat
```

Capabilities SHOULD be independently testable.

---

# 38. Adding a New Service

A new service MUST define:

```text
Purpose
Owner
Inputs
Outputs
Failure semantics
State
Configuration
Identity
Privilege
Network exposure
Observability
Tests
Recovery
Consumers
```

A service SHOULD expose a stable contract rather than exposing its internal
implementation.

---

# 39. AI Agent Architecture Contract

AI agents are first-class engineering contributors but NOT architectural
authority.

Before modifying architecture, an AI agent MUST:

1. inspect repository state;
2. inspect relevant domain manifests;
3. inspect capabilities;
4. inspect ownership;
5. inspect dependencies;
6. inspect exceptions;
7. inspect ADRs where relevant;
8. search for existing implementations;
9. define the required invariant;
10. create or update verification;
11. implement the smallest correct change;
12. run verification;
13. update architecture metadata;
14. update documentation where required.

---

## 39.1 AI agents MUST NOT

AI agents MUST NOT:

* invent architectural authority;
* create a new domain without justification;
* duplicate capabilities;
* bypass contracts;
* weaken architecture tests;
* suppress security failures;
* hide cross-domain dependencies;
* introduce hardcoded secrets;
* invent unsupported Nix options;
* infer runtime success from static evaluation;
* silently alter host capabilities;
* bypass the approved Git workflow;
* silently change architecture schema;
* remove a failing test to make CI pass.

---

## 39.2 AI decision flow

Before adding an implementation:

```text
Does capability already exist?
        │
        ├── YES → reuse / extend
        │
        └── NO
             │
             ▼
Is there an existing owner?
             │
             ├── YES → implement in that domain
             │
             └── NO
                  │
                  ▼
             justify capability/domain
```

---

# 40. Architecture Review Checklist

Every material architectural change SHOULD answer:

## Ownership

```text
Who owns this capability?
What state does it own?
What configuration does it own?
```

## Boundary

```text
What crosses the boundary?
How is it authenticated?
How is it authorized?
```

## Dependency

```text
What does this depend on?
Who depends on it?
Does it introduce a cycle?
```

## Security

```text
What privilege is required?
What secret access is required?
What network exposure exists?
What happens if compromised?
```

## Reliability

```text
How does it fail?
How is failure detected?
How is it recovered?
What are the RPO/RTO/SLO implications?
```

## Observability

```text
How do we know it works?
How do we know it is degraded?
How do we diagnose failure?
```

## Testing

```text
What test proves the intended behavior?
What negative test proves the boundary?
```

## Migration

```text
What old behavior is replaced?
How is the migration verified?
How is rollback performed?
```

---

# 41. Definition of Architectural Done

A material architectural change is complete only when:

## Architecture

* [ ] Domain ownership is explicit.
* [ ] Capability ownership is explicit.
* [ ] Dependencies are explicit.
* [ ] No undocumented boundary violation exists.
* [ ] No circular dependency was introduced.
* [ ] Exceptions are documented where required.
* [ ] Machine-readable architecture metadata is updated.

## Configuration

* [ ] Configuration has one authoritative source.
* [ ] No duplicate ownership exists.
* [ ] Host-specific configuration is scoped correctly.

## Security

* [ ] Least privilege is maintained.
* [ ] Secret access is minimized.
* [ ] Network exposure is intentional.
* [ ] Filesystem access is intentional.
* [ ] Security controls are tested.

## Reliability

* [ ] Failure modes are understood.
* [ ] Health checks exist where appropriate.
* [ ] Recovery behavior is defined.
* [ ] Rollback behavior is defined.
* [ ] RPO/RTO/SLO implications are understood.

## TDD / Verification

* [ ] Behavior was defined first.
* [ ] Verification was written or updated first where practical.
* [ ] Tests pass.
* [ ] Negative behavior is tested where appropriate.
* [ ] Regression coverage exists.

## Operations

* [ ] Logs exist.
* [ ] Metrics exist where useful.
* [ ] Health status is exposed.
* [ ] Alerts exist for actionable failures.

## Supply chain

* [ ] Dependencies are pinned/reviewable.
* [ ] CI trust is appropriate.
* [ ] Artifact provenance is preserved where required.
* [ ] Deployment source is attributable.

## Documentation

* [ ] `ARCHITECTURE.md` reflects the target architecture.
* [ ] Relevant manifests are updated.
* [ ] ADR created or updated where warranted.
* [ ] Exceptions updated where relevant.

## Delivery

* [ ] `ivali flow` followed.
* [ ] CI passes.
* [ ] Deployment is verified.
* [ ] Runtime behavior is verified where possible.

---

# 42. Final Target Architecture

The target system is:

```text
                                  OPERATOR
                                     │
                                     ▼
                         ┌────────────────────────┐
                         │    IVALI CONTROL PLANE │
                         │        CLI / UI        │
                         └────────────┬───────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │ DOMAIN ORCHESTRATION   │
                         └────────────┬───────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
                GitOps            Platform           Recovery
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │    SERVICE CONTRACTS   │
                         ├────────────────────────┤
                         │ Health                 │
                         │ Metrics                │
                         │ Backup                 │
                         │ Notification           │
                         │ Platform               │
                         └────────────┬───────────┘
                                      │
                                      ▼
                     ┌────────────────────────────────┐
                     │ INFRASTRUCTURE ADAPTERS        │
                     ├────────────────────────────────┤
                     │ NixOS                          │
                     │ systemd                        │
                     │ filesystem                     │
                     │ networking                     │
                     │ observability backends         │
                     │ recovery backends              │
                     └───────────────┬────────────────┘
                                     │
                                     ▼
                     ┌────────────────────────────────┐
                     │         NIXOS DOMAINS          │
                     ├────────────────────────────────┤
                     │ boot                           │
                     │ hardware                       │
                     │ system                         │
                     │ storage                        │
                     │ networking                     │
                     │ security                       │
                     │ ssh                            │
                     │ desktop                        │
                     │ home                           │
                     │ services                       │
                     │ observability                  │
                     │ automation                     │
                     │ recovery                       │
                     └───────────────┬────────────────┘
                                     │
                                     ▼
                     ┌────────────────────────────────┐
                     │           HOSTS                │
                     ├────────────────────────────────┤
                     │ Prague                         │
                     │ Tuscany                        │
                     │ Test VM / other hosts          │
                     │ Oracle Edge                    │
                     └────────────────────────────────┘
```

---

# 42.1 Prague target architecture

```text
                              PRAGUE
                                │
       ┌────────────────────────┼────────────────────────┐
       │                        │                        │
       ▼                        ▼                        ▼
   GNOME Desktop           Remote Access           Gateway
       │                        │                        │
       │                     Tailscale                  │
       │                        │                        │
       │                  SSH / GNOME RDP               │
       │                        │                        │
       │                     tmux                       │
       │                                                 │
       └──────────────────────────────┬──────────────────┘
                                      │
                                Tailscale
                                Exit Node
                                      │
                                      ▼
                                   Internet
```

---

# 42.2 LAN architecture

```text
Phone
  │
  │ local LAN
  ▼
Prague
  │
  └── LocalSend :53317
```

LocalSend is LAN-oriented and is not automatically a Tailscale service.

---

# 42.3 Remote administration architecture

```text
Phone
  │
  │ Tailscale
  ▼
Prague
  │
  ▼
SSH
  │
  ▼
tmux
  │
  ▼
maintenance
```

Interactive SSH enters the persistent maintenance session.

Non-interactive SSH remains unaffected.

---

# 42.4 Deployment architecture

```text
Developer
   ↓
Feature branch
   ↓
TDD / verification
   ↓
Merge request
   ↓
Architecture checks
   ↓
Security checks
   ↓
Host matrix evaluation/build
   ↓
Approved merge
   ↓
Artifact / desired state
   ↓
GitOps reconciliation
   ↓
Privileged activation
   ↓
Boot/runtime health
   ├── healthy → accepted
   └── failed  → rollback
```

---

# 42.5 Recovery architecture

```text
                  DEPLOYMENT
                      │
                      ▼
                NEW GENERATION
                      │
                      ▼
                 HEALTH GATE
                 /         \
                /           \
           HEALTHY          FAILED
              │                │
              ▼                ▼
          ACCEPTED          ROLLBACK
                                 │
                                 ▼
                         KNOWN-GOOD GENERATION
                                 │
                                 ▼
                            VERIFY HEALTH
```

---

# 43. Core Architectural Invariants

The following invariants are foundational.

```text
1. One capability has one authoritative owner.

2. Hosts compose domains; hosts do not implement reusable domains.

3. Every host has explicit hardware/profile boundaries.

4. Host capabilities are explicit.

5. Domains communicate through explicit contracts.

6. Private domain state is not directly consumed by unrelated domains.

7. Configuration has one authoritative source.

8. Persistent state has one authoritative owner.

9. Secrets have explicit ownership and lifecycle.

10. Architecture dependencies remain acyclic unless explicitly excepted.

11. Architecture exceptions are documented, owned, reviewed, and removable.

12. Dangerous capabilities default to disabled unless explicitly required.

13. Prague is an intentional exception:
    Tailscale and exit-node capability are permanent architectural requirements.

14. The known-working Tailscale ACL remains the baseline until an explicitly
    validated migration is approved.

15. Local network services are not automatically remote services.

16. CI must not receive unnecessary privileged trust.

17. Deployment privilege must be narrower than source-code execution authority.

18. Deployment failures must remain observable.

19. Recovery is a designed capability.

20. A known-good generation must remain recoverable.

21. Architecture constraints should be executable.

22. Behavior-changing work is verification-first.

23. Security tests cover both permitted and forbidden behavior.

24. Supply-chain provenance should connect source to deployment.

25. AI agents are contributors, not architectural authorities.

26. Current repository state describes reality; architectural policy determines
    whether that reality is acceptable.

27. A successful build alone does not establish architectural correctness.

28. Runtime success must not be inferred from static evaluation.

29. Architectural documentation must not contradict machine-readable policy.

30. The architecture must optimize for clarity, security, reliability,
    reproducibility, and recoverability rather than maximum abstraction.
```

---

# 44. Architecture Operating Loop

The repository's intended engineering loop is:

```text
                        ┌────────────────────┐
                        │ DISCOVER CURRENT    │
                        │      REALITY        │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │ CHECK ARCHITECTURE  │
                        │      POLICY         │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │ DEFINE INVARIANT    │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │ WRITE VERIFICATION  │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │     IMPLEMENT      │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │      VERIFY        │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │     REFACTOR       │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │ ARCHITECTURE TEST  │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │ INTEGRATION TEST   │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │ SECURITY REVIEW    │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │ RUNTIME VALIDATION │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │   IVALI FLOW       │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │    CI / GITOPS     │
                        └─────────┬──────────┘
                                  │
                                  ▼
                        ┌────────────────────┐
                        │ DEPLOY / OBSERVE   │
                        └─────────┬──────────┘
                                  │
                                  └──────────────► IMPROVE
```

The architecture is considered healthy when this loop is continuously
reinforced by executable policy.

---

# Closing Statement

The purpose of this architecture is not to maximize abstraction or produce
the largest possible number of files.

The purpose is to make the system:

```text
Explicit
     +
Reproducible
     +
Secure
     +
Observable
     +
Testable
     +
Recoverable
     +
Maintainable
```

The correct implementation should be the easiest implementation to verify.

The incorrect implementation should be difficult to introduce silently.

**Architecture is successful when the repository itself helps enforce the
architecture.**
