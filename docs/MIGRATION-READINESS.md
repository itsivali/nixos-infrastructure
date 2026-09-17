# Migration Readiness — GNOME → KDE Plasma + Elixir/OTP Refactor

**Status:** `NOT READY`
**Migration authorization:** `BLOCKED`
**Primary migration:** GNOME → KDE Plasma
**Strategic runtime migration:** Go → Elixir/OTP
**Migration model:** staged, test-driven, reversible

---

## 1. Purpose

The repository is entering a broader platform transition with two related but distinct objectives:

1. **Desktop migration:** GNOME → KDE Plasma
2. **Runtime migration:** Go → Elixir/OTP

These migrations must not be treated as one large rewrite.

The immediate objective is to establish **KDE Plasma as the supported desktop platform** while preserving the existing NixOS infrastructure, security model, networking, observability, deployment, and recovery capabilities.

Once the desktop platform is stable, the longer-term objective is to introduce **Elixir/OTP as a first-class runtime platform** for selected infrastructure services and automation.

The governing principle is:

> **Migrate the platform in controlled layers. Stabilize KDE first, establish the runtime architecture, then migrate services incrementally to Elixir/OTP.**

Neither migration may be used to conceal instability in the other.

---

# 2. Migration Tracks

The program consists of two tracks.

```text
                         MIGRATION PROGRAM
                                │
                ┌───────────────┴───────────────┐
                │                               │
         TRACK A — DESKTOP              TRACK B — RUNTIME
                │                               │
          GNOME → KDE Plasma                Go → Elixir/OTP
                │                               │
                └───────────────┬───────────────┘
                                │
                       Shared Architecture
                                │
             ┌──────────────────┼──────────────────┐
             │                  │                  │
          Security          Observability       Recovery
             │                  │                  │
             └──────────────────┼──────────────────┘
                                │
                           Ivali Flow
                                │
                          TDD + CI + GitOps
```

### Track A — Desktop

The desktop migration covers:

* GNOME removal;
* KDE Plasma installation;
* SDDM/session management;
* KDE configuration;
* KWin;
* Wayland/X11 compatibility;
* KDE portals;
* D-Bus;
* PipeWire/WirePlumber;
* Bluetooth;
* NetworkManager;
* external displays;
* suspend/resume;
* screen sharing;
* camera/microphone;
* remote GUI access;
* application integration;
* Firefox/Sidebery;
* desktop theming;
* resource consumption.

### Track B — Runtime

The runtime migration covers:

* Go service contracts;
* Elixir/OTP architecture;
* supervision trees;
* service boundaries;
* observability;
* state ownership;
* infrastructure adapters;
* systemd integration;
* Nix packaging;
* deployment;
* rollback;
* eventual retirement of selected Go services.

---

# 3. Migration Principles

## 3.1 Stabilize before replacing

Neither migration begins from an unknown baseline.

The existing system must first be:

* reproducible;
* testable;
* observable;
* secure;
* recoverable;
* architecturally enforceable.

---

## 3.2 KDE is a platform migration

KDE Plasma must not be treated as simply installing another desktop package.

The migration includes the complete desktop stack:

```text
SDDM
  ↓
Plasma Session
  ↓
KWin
  ↓
Wayland / X11
  ↓
D-Bus
  ↓
Portals
  ↓
PipeWire / WirePlumber
  ↓
NetworkManager / Bluetooth
  ↓
Applications
  ↓
Remote access / sharing
```

A successful login is therefore **not** sufficient to declare the migration complete.

---

## 3.3 Elixir is not a desktop replacement

Elixir/OTP will not replace KDE Plasma.

Instead:

```text
KDE Plasma
     │
     │ desktop/user-facing platform
     ▼
NixOS
     │
     │ system integration
     ▼
Infrastructure Services
     │
     ▼
Elixir/OTP
```

Elixir may eventually provide:

* orchestration;
* automation;
* health coordination;
* reconciliation;
* event processing;
* service APIs;
* platform control-plane functionality.

It must not become a second desktop framework.

---

# 4. Architecture Authority

The migration follows the repository architecture model.

The authoritative architecture chain is:

```text
ARCHITECTURE.md
        ↓
ARCHITECTURE_AUDIT.md
        ↓
ARCHITECTURE_PROGRESS.md
        ↓
architecture/
 ├── domains.yaml
 ├── dependencies.yaml
 └── exceptions.yaml
        ↓
Architecture Tests
        ↓
Architecture Linter
        ↓
CI
```

The governing invariant remains:

> **Hosts compose capabilities. Domains own capabilities. Services expose contracts. Infrastructure adapters implement those contracts.**

The desktop migration must therefore introduce KDE as a **desktop capability/domain**, rather than scattering KDE-specific configuration throughout unrelated domains.

---

# 5. KDE Desktop Target Architecture

The target desktop architecture is:

```text
                    KDE Plasma
                         │
              ┌──────────┼──────────┐
              │          │          │
             KWin       D-Bus     Portals
              │          │          │
              └──────────┼──────────┘
                         │
             ┌───────────┴───────────┐
             │                       │
        PipeWire                  Network
        WirePlumber               Manager
             │                       │
       Audio/Video              Wi-Fi/VPN
             │                       │
             └───────────┬───────────┘
                         │
                    Applications
```

## Desktop requirements

KDE must provide:

* reliable login;
* reliable logout;
* suspend/resume;
* display management;
* audio;
* microphone;
* camera;
* Bluetooth;
* Wi-Fi;
* screen sharing;
* desktop notifications;
* application launching;
* clipboard;
* file integration;
* portals;
* authentication prompts;
* remote GUI access;
* acceptable idle resource consumption.

---

# 6. KDE Theme and User Experience

The target visual environment is based on the **Garuda Mokka** design direction.

The theme is presentation only; it must not compromise:

* accessibility;
* stability;
* updateability;
* performance;
* security;
* maintainability.

The KDE migration must maintain a coherent experience across:

* Plasma;
* KWin;
* application styling;
* GTK applications;
* Qt applications;
* icons;
* fonts;
* cursor;
* terminal;
* file manager;
* browser;
* notifications;
* login/session experience.

The desired result is a cohesive KDE workstation rather than a collection of independently themed applications.

---

# 7. Desktop Application Baseline

The migration must explicitly inventory the applications currently integrated into GNOME.

For every GNOME-dependent component:

```text
Existing component
       ↓
Purpose identified
       ↓
KDE replacement?
       │
       ├── Yes → replace
       │
       ├── No → retain independently
       │
       └── Obsolete → remove
```

The migration must identify and remove obsolete GNOME dependencies rather than leaving a hidden GNOME runtime underneath KDE.

### Examples of migration areas

* application launcher;
* desktop menu;
* dock/panel;
* notifications;
* settings;
* file management;
* authentication dialogs;
* screen capture;
* screenshot tooling;
* clipboard;
* power management;
* display management;
* network UI;
* Bluetooth UI;
* audio controls.

---

# 8. Firefox Desktop Integration

Firefox remains a first-class application.

The desktop migration must preserve:

* Firefox profile;
* bookmarks;
* extensions;
* Sidebery;
* vertical-tab workflow;
* microphone permissions;
* camera permissions;
* screen sharing;
* PipeWire integration;
* KDE portal integration;
* hardware acceleration where supported.

The migration must not assume that a browser working under GNOME automatically works correctly under KDE.

---

# 9. Desktop Remote Access

Remote GUI access is part of the acceptance surface.

The desired architecture is:

```text
Phone / Windows App
        │
        │ encrypted transport
        ▼
     Tailscale
        │
        ▼
      Prague
        │
        ▼
    KDE Plasma
        │
        ▼
       KWin
```

Remote access must be:

* private by default;
* Tailscale-restricted where possible;
* authenticated;
* encrypted;
* auditable;
* independently disableable.

Remote GUI access must not expose an unnecessary public RDP service.

---

# 10. Desktop Security

KDE migration must preserve the existing security model.

The migration must not weaken:

* SOPS/age;
* AppArmor;
* nftables;
* SSH hardening;
* sudo/polkit;
* Tailscale ACLs;
* service sandboxing;
* secret handling;
* filesystem permissions.

KDE-specific services must receive only the privileges they require.

---

# 11. Desktop Acceptance Gates

## D1 — GNOME Inventory

Before removing GNOME:

* [ ] All GNOME packages are inventoried.
* [ ] GNOME services are identified.
* [ ] GNOME extensions are inventoried.
* [ ] GNOME-specific configuration is identified.
* [ ] GNOME-specific environment variables are identified.
* [ ] GNOME-specific portals/services are identified.
* [ ] GNOME dependencies of applications are identified.
* [ ] Required functionality has a KDE-compatible implementation or an explicit independent implementation.

---

## D2 — KDE Installation

* [ ] KDE Plasma evaluates from the flake.
* [ ] KDE configuration is declarative.
* [ ] SDDM configuration is declarative.
* [ ] Plasma session starts successfully.
* [ ] Wayland session is tested.
* [ ] X11 fallback is understood and tested where required.
* [ ] No undocumented manual configuration is required.

---

## D3 — Desktop Functionality

The following must be tested on real hardware:

* [ ] Wi-Fi.
* [ ] Bluetooth.
* [ ] Ethernet where applicable.
* [ ] Audio output.
* [ ] Microphone.
* [ ] Camera.
* [ ] Screen sharing.
* [ ] External display.
* [ ] Display scaling.
* [ ] Brightness.
* [ ] Suspend.
* [ ] Resume.
* [ ] Power management.
* [ ] Keyboard.
* [ ] Touchpad.
* [ ] Clipboard.
* [ ] Notifications.
* [ ] File management.
* [ ] Application launching.

---

## D4 — Browser/Media

* [ ] Firefox launches.
* [ ] Sidebery works.
* [ ] Vertical tabs work.
* [ ] Microphone permissions work.
* [ ] Camera permissions work.
* [ ] Google Meet works.
* [ ] Screen sharing works.
* [ ] PipeWire audio works.
* [ ] WirePlumber device management works.

---

## D5 — Remote Desktop

* [ ] Remote KDE session is accessible.
* [ ] Tailscale transport works.
* [ ] Authentication works.
* [ ] Clipboard behavior is understood.
* [ ] Audio behavior is understood.
* [ ] Display behavior is acceptable.
* [ ] Session isolation is correct.
* [ ] Public exposure is not required.

---

# 12. Security and Secrets Gate

The desktop and runtime migrations share one security architecture.

Required:

* [ ] Secrets remain exclusively under the approved SOPS/age model.
* [ ] No secrets are embedded into Nix derivations.
* [ ] No credentials are placed in KDE configuration files.
* [ ] No credentials are embedded in Elixir configuration.
* [ ] Runtime secrets are delivered through the approved runtime mechanism.
* [ ] AppArmor policies are updated where required.
* [ ] nftables ownership remains singular.
* [ ] Tailscale ACLs remain authoritative.
* [ ] Service privileges are minimized.
* [ ] Security scanning remains green.

### Break-glass

* [ ] SOPS break-glass recovery mechanism decided.
* [ ] Recovery procedure documented.
* [ ] Recovery procedure tested.

---

# 13. Tailscale and Zero-Trust Boundary

Tailscale remains the secure transport layer for remote access and infrastructure connectivity.

The model is:

```text
Identity
   +
Tailscale ACL
   +
Host firewall
   +
Service authentication
   +
Application authorization
```

Tailscale connectivity alone must not imply application-level trust.

The KDE remote-access path must therefore remain subject to the same security model as other infrastructure services.

---

# 14. Elixir/OTP Architecture Gate

The Elixir migration cannot begin until the target architecture is defined.

The architecture briefing must define:

### Runtime

* OTP application boundaries;
* supervision trees;
* process ownership;
* restart strategies;
* graceful shutdown;
* failure isolation.

### Domains

* domain ownership;
* dependency direction;
* forbidden dependencies;
* cross-domain interfaces.

### Services

For each migration-target service:

```text
Responsibility
Contract
State
Configuration
Dependencies
Security
Health
Metrics
Logging
Failure behavior
Recovery
```

---

# 15. Existing Go Service Contracts

The existing Go service architecture remains the contract baseline.

Relevant service abstractions include:

```text
BackupService
MetricsProvider
HealthChecker
NotificationService
PlatformService
```

The Elixir implementation must satisfy the **behavioral contract**, not reproduce the internal Go structure.

The migration should avoid mechanically translating Go packages into Elixir modules.

Instead:

```text
Go implementation
       ↓
Extract behavior
       ↓
Define contract
       ↓
Define domain boundary
       ↓
Elixir architecture
       ↓
OTP implementation
```

---

# 16. Elixir Supervision Model

Elixir services must exploit OTP appropriately.

The goal is not to reproduce systemd inside Elixir.

The responsibilities should remain separated:

```text
systemd
  │
  └── owns OS-level service lifecycle
          │
          ▼
       OTP app
          │
          ├── supervision
          ├── processes
          ├── internal recovery
          └── application-level health
```

systemd handles:

* process startup;
* service restart;
* OS-level sandboxing;
* dependencies;
* shutdown;
* resource controls.

OTP handles:

* process supervision;
* application-level failure isolation;
* worker lifecycle;
* internal concurrency;
* internal recovery.

---

# 17. Runtime Regression Gate

Before replacing a Go service:

* [ ] Go implementation is stable.
* [ ] Contract tests exist.
* [ ] Elixir implementation passes contract tests.
* [ ] Architecture checks pass.
* [ ] Security checks pass.
* [ ] Observability is equivalent.
* [ ] State ownership is unchanged or explicitly migrated.
* [ ] Failure behavior is tested.
* [ ] Recovery behavior is tested.
* [ ] Deployment is tested.
* [ ] Rollback is tested.

---

# 18. Dual-Run Requirement

Where appropriate:

```text
             Contract
                │
        ┌───────┴───────┐
        │               │
       Go            Elixir
        │               │
        └───────┬───────┘
                │
          Compare results
                │
          Health / metrics
```

There must be no uncontrolled dual ownership of authoritative state.

The migration must explicitly identify:

* writer;
* reader;
* authority;
* comparison mechanism;
* discrepancy handling;
* cutover mechanism;
* rollback mechanism.

---

# 19. Observability

Both migration tracks must use the existing observability architecture.

Required signals include:

* service health;
* system health;
* logs;
* metrics;
* deployment status;
* rollback state;
* desktop health;
* network health;
* audio health;
* display health;
* resource consumption.

Observability remains a **consumer of system state**, not the owner of another domain's state.

---

# 20. Self-Healing

Self-healing must remain bounded and evidence-driven.

The recovery hierarchy is:

```text
Detect
  ↓
Diagnose
  ↓
Attempt bounded recovery
  ↓
Verify recovery
  ↓
Escalate
  ↓
Rollback when appropriate
```

The system must not repeatedly restart a failing component indefinitely.

Recovery requires:

* retry limits;
* backoff;
* hysteresis;
* health verification;
* escalation;
* rollback;
* operator visibility.

A transient Wi-Fi failure, for example, must not trigger an unrelated system-generation rollback.

---

# 21. GitOps and Ivali Flow

Both migrations remain under Ivali Flow.

The workflow is:

```text
Change
 ↓
Understand
 ↓
Classify
 ↓
Investigate
 ↓
Plan
 ↓
TDD
 ↓
RED
 ↓
Implement
 ↓
GREEN
 ↓
Refactor
 ↓
Verify
 ↓
MR / CI
 ↓
Merge
 ↓
GitOps reconciliation
 ↓
Generation switch
 ↓
Health validation
 ↓
Observe
 ↓
Rollback if necessary
```

AI agents must not bypass this workflow.

No migration component may be accepted merely because an AI agent reports that it works.

Evidence must come from actual repository checks, tests, evaluation, builds, runtime verification, or CI.

---

# 22. Migration Order

The recommended sequence is:

## Stage 1 — Stabilize existing NixOS

Complete the baseline gates.

```text
NixOS + Go
      ↓
Known-good baseline
```

## Stage 2 — Migrate GNOME → KDE

Complete the desktop migration while retaining the existing Go infrastructure.

```text
NixOS
  │
  ├── KDE Plasma
  └── Existing Go platform
```

## Stage 3 — Stabilize KDE

Operate KDE long enough to validate:

* hardware;
* networking;
* audio;
* display;
* browser;
* remote access;
* power;
* resource usage.

## Stage 4 — Approve Elixir Architecture

Only after the KDE baseline is stable:

```text
KDE baseline
     +
NixOS baseline
     +
Architecture baseline
     ↓
Elixir architecture approval
```

## Stage 5 — Introduce Elixir Foundation

Add the minimum OTP runtime required for the first service.

## Stage 6 — Migrate One Service

Use:

```text
Contract
→ Tests
→ Elixir
→ Dual-run
→ Cutover
→ Observe
→ Stabilize
```

## Stage 7 — Repeat

Only after the previous service is stable.

## Stage 8 — Retire Go

Remove Go components only after Elixir has demonstrated stable operational ownership.

---

# 23. Definitive Blockers

| ID  | Blocker                                      | Why it blocks migration                       |
| --- | -------------------------------------------- | --------------------------------------------- |
| B1  | SOPS break-glass strategy unresolved         | Recovery architecture is incomplete           |
| B2  | GNOME desktop inventory incomplete           | KDE migration could leave hidden dependencies |
| B3  | KDE hardware validation incomplete           | Desktop baseline is unverified                |
| B4  | KDE audio/microphone verification incomplete | Real hardware acceptance is incomplete        |
| B5  | KDE remote-access architecture unverified    | Remote operations remain unproven             |
| B6  | Elixir/OTP architecture briefing missing     | Runtime target is undefined                   |
| B7  | Elixir architecture enforcement missing      | New runtime could bypass architecture rules   |
| B8  | Service contracts incomplete                 | Behavioral migration target is ambiguous      |
| B9  | Dual-run/cutover strategy incomplete         | Migration remains irreversible                |
| B10 | Current architecture audit incomplete        | Existing violations may contaminate migration |

**Any unresolved mandatory blocker keeps migration status at `NOT READY`.**

---

# 24. Non-Blocking Work

The following may continue independently:

| ID   | Work                             | Status   |
| ---- | -------------------------------- | -------- |
| NB1  | CI deployment gate parity        | Complete |
| NB2  | `gosec` enforcement              | Complete |
| NB3  | `flow merge` pipeline handling   | Complete |
| NB4  | CI platform parity               | Complete |
| NB5  | KDE theme refinement             | Ongoing  |
| NB6  | Firefox/Sidebery refinement      | Ongoing  |
| NB7  | Desktop performance optimization | Ongoing  |
| NB8  | Oracle ARM64 edge planning       | Planned  |
| NB9  | Observability improvements       | Ongoing  |
| NB10 | Architecture documentation       | Ongoing  |

These activities must not silently create a dependency on Elixir.

---

# 25. Fresh-Checkout Acceptance

A clean checkout must be capable of reaching a known-good baseline.

Conceptually:

```text
Fresh checkout
      ↓
Locked dependencies
      ↓
Nix evaluation
      ↓
Architecture validation
      ↓
Tests
      ↓
Build
      ↓
Desktop configuration
      ↓
KDE session
      ↓
Infrastructure services
      ↓
Health checks
      ↓
GREEN
```

No undocumented manual fixes are acceptable.

---

# 26. Definition of Migration Entry

Migration entry is authorized only when:

* [ ] Existing NixOS baseline is green.
* [ ] Regression suite is green.
* [ ] Security baseline is green.
* [ ] Architecture enforcement is green.
* [ ] GNOME dependencies are fully inventoried.
* [ ] KDE evaluates declaratively.
* [ ] KDE session works on real hardware.
* [ ] Audio and microphone work.
* [ ] Camera/screen sharing work.
* [ ] Wi-Fi/Bluetooth work.
* [ ] External displays work.
* [ ] Suspend/resume works.
* [ ] Firefox/Sidebery work.
* [ ] Remote GUI access works securely.
* [ ] KDE resource usage is acceptable.
* [ ] SOPS break-glass strategy is resolved.
* [ ] Elixir/OTP target architecture is approved.
* [ ] Service contracts are migration-ready.
* [ ] Elixir architecture enforcement is implemented.
* [ ] Dual-run strategy exists.
* [ ] Rollback is demonstrated.
* [ ] CI enforces the required boundaries.
* [ ] Fresh checkout reaches the green baseline.

---

# 27. Definition of Migration Completion

The entire migration program is complete only when:

```text
GNOME
  ↓
Removed

KDE Plasma
  ↓
Stable + Declarative + Supported

Go Runtime
  ↓
Gradually Retired

Elixir/OTP
  ↓
Contract-compliant + Observable + Recoverable

Architecture
  ↓
Machine-enforced

Deployment
  ↓
GitOps + Ivali Flow

Recovery
  ↓
Tested + Observable
```

Completion does **not** mean every Go component must automatically be rewritten in Elixir.

A service should remain in Go if there is no demonstrated architectural or operational reason to migrate it.

---

# 28. Final Migration Invariant

At every stage of the program:

> **The workstation must remain usable, the infrastructure must remain recoverable, the architecture must remain enforceable, and every migration step must be reversible.**

The migration therefore follows:

```text
             STABILIZE
                 ↓
          INVENTORY GNOME
                 ↓
           DEFINE KDE
                 ↓
        TEST REAL HARDWARE
                 ↓
          STABILIZE KDE
                 ↓
      DEFINE ELIXIR ARCHITECTURE
                 ↓
       EXTRACT SERVICE CONTRACTS
                 ↓
        IMPLEMENT OTP SERVICE
                 ↓
             DUAL RUN
                 ↓
          CONTROLLED CUTOVER
                 ↓
            OBSERVE
                 ↓
          STABILIZE
                 ↓
       RETIRE LEGACY SERVICE
                 ↓
              REPEAT
```

## Engineering Principle

> **KDE is the immediate desktop destination. Elixir/OTP is the strategic runtime destination. NixOS remains the declarative foundation. Ivali Flow remains the engineering and deployment control plane. Architecture enforcement remains the guardrail.**

The goal is not simply to replace GNOME or rewrite Go.

The goal is to evolve the platform without losing:

**reproducibility → security → observability → testability → recoverability → architectural integrity → operational simplicity.**

