# Architecture Progress

> Tracks the migration from the current repository architecture toward the target architecture defined in `ARCHITECTURE.md`, using `ARCHITECTURE_AUDIT.md` as the evidence-based conformance record.
>
> **Last updated:** Session 9
> **Status:** Architecture enforcement operational; remaining work is primarily consolidation, re-audit, and controlled migration of legacy boundaries.

---

## 1. Purpose

`ARCHITECTURE_PROGRESS.md` is the **migration and implementation status document** for the repository architecture.

It answers:

* What architectural work has been completed?
* What remains to be migrated?
* Which audit findings have been resolved?
* Which findings remain open?
* Which architecture controls are already enforced?
* What verification has passed?
* What is the next architectural action?

It does **not** define the architecture itself.

The repository architecture is defined by:

* `ARCHITECTURE.md` — target architecture and architectural rules
* `ARCHITECTURE_AUDIT.md` — current-state evidence and conformance assessment
* `architecture/domains.yaml` — domain declarations
* `architecture/dependencies.yaml` — dependency declarations
* `architecture/exceptions.yaml` — explicitly approved exceptions
* Architecture tests and linter — executable architectural enforcement

---

# 2. Architectural End State

The migration is working toward the following invariant:

```text
Hosts compose capabilities.
Domains own capabilities.
Services expose contracts.
Infrastructure adapters implement contracts.
```

The intended dependency direction is:

```text
HOST
  │
  ▼
DOMAIN
  │
  ▼
APPLICATION / ORCHESTRATION
  │
  ▼
SERVICE CONTRACT
  │
  ▼
INFRASTRUCTURE ADAPTER
  │
  ▼
EXTERNAL SYSTEM
```

The following principles remain mandatory:

1. Hosts compose domains; domains do not depend on hosts.
2. Domains own their capabilities and state.
3. Cross-domain dependencies are explicit.
4. Service consumers depend on contracts rather than concrete implementations.
5. Infrastructure adapters implement service contracts.
6. A state path has one authoritative owner.
7. Configuration has one authoritative owner.
8. Network ports have one authoritative owner.
9. Secrets have one authoritative management path.
10. Exceptions are explicit, documented, owned, and reviewable.
11. Architecture rules are executable wherever practical.
12. CI must prevent architectural regression.
13. Recovery and deployment paths must remain independently understandable.
14. Observability observes system state; it does not become the owner of another domain's state.

---

# 3. Migration Status

| Phase | Area                                      | Status                       |
| ----- | ----------------------------------------- | ---------------------------- |
| 0     | Re-audit current repository               | **In progress / continuous** |
| 1     | Machine-readable architecture             | **Complete**                 |
| 2     | State and filesystem ownership            | **Substantially complete**   |
| 3     | Configuration ownership and consolidation | **In progress**              |
| 4     | Service contracts                         | **Substantially complete**   |
| 5     | Consumer migration                        | **In progress**              |
| 6     | Legacy implementation removal             | **In progress**              |
| 7     | Continuous architecture enforcement       | **Operational**              |

The architecture is therefore no longer dependent solely on documentation.

It is progressively moving through:

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

---

# 4. Phase 0 — Continuous Re-Audit

## Objective

Ensure architectural decisions and historical findings remain accurate against the **current repository**, rather than treating historical audit results as permanent truth.

## Completed

* [x] Repository structure audited.
* [x] Domain boundaries documented.
* [x] Dependency relationships identified.
* [x] State ownership reviewed.
* [x] Filesystem boundaries reviewed.
* [x] Service contracts identified.
* [x] Historical architectural violations catalogued.
* [x] Historical exceptions reviewed.
* [x] Architecture linter introduced.
* [x] Architecture tests introduced.

## Ongoing

* [ ] Revalidate every historical violation against the current tree.
* [ ] Remove findings that no longer exist.
* [ ] Convert unresolved findings into explicit migration tasks.
* [ ] Ensure every exception still has a valid owner and reason.
* [ ] Ensure audit evidence references current repository paths.
* [ ] Periodically rerun the complete architectural inventory.

### Rule

Historical findings are **evidence**, not current truth.

Every historical violation must eventually be classified as:

```text
RESOLVED
RETAINED AS VALID EXCEPTION
MIGRATION REQUIRED
NO LONGER APPLICABLE
```

---

# 5. Phase 1 — Machine-Readable Architecture

## Objective

Move architectural rules from prose into machine-readable declarations and executable validation.

## Completed

* [x] `architecture/domains.yaml`
* [x] `architecture/dependencies.yaml`
* [x] `architecture/exceptions.yaml`
* [x] Domain declarations introduced.
* [x] Dependency declarations introduced.
* [x] Exception declarations introduced.
* [x] Architecture linter integrated into validation.
* [x] Architecture tests introduced.
* [x] CI enforcement integrated.

## Current State

The architecture is now represented by both:

```text
Human-readable architecture
        +
Machine-readable architecture
        +
Executable architecture tests
        +
Architecture linter
```

## Remaining

* [ ] Continue expanding machine-readable ownership metadata where useful.
* [ ] Ensure every new domain is explicitly declared.
* [ ] Ensure every cross-domain dependency is declared.
* [ ] Prevent undocumented exceptions from entering the repository.

---

# 6. Phase 2 — State and Filesystem Ownership

## Objective

Establish clear ownership for persistent state and prevent implicit cross-domain filesystem dependencies.

## Completed

* [x] `/var/lib/gitops` ownership formalized.
* [x] GitOps state ownership documented.
* [x] Filesystem boundary violations identified.
* [x] Existing filesystem exceptions documented.
* [x] `service_state_ownership` architecture rule enabled.
* [x] P0 state ownership violation resolved.
* [x] CI/automation shared-state behavior explicitly documented through an architecture exception.

## Historical Findings Addressed

The following areas were identified during the audit:

* `/var/lib/gitops`
* `/var/lib/observability`
* `/var/lib/health-endpoint`
* `/var/lib/prometheus`
* `/var/lib/loki`
* `/var/lib/attic`
* `/var/lib/tailscale-metrics`
* `/var/lib/gitlab-runner-health`
* `/var/lib/deployment-health`
* `/var/lib/security-scanner`
* `/var/lib/valkey`

These must continue to be treated as ownership boundaries rather than arbitrary filesystem locations.

## Remaining

* [ ] Revalidate every historical state path.
* [ ] Ensure systemd `StateDirectory` is used where appropriate.
* [ ] Replace implicit consumers with explicit service contracts where practical.
* [ ] Remove obsolete filesystem exceptions when migrations complete.

---

# 7. Phase 3 — Configuration Ownership and Consolidation

## Objective

Ensure each architectural concern has one authoritative configuration source.

## Completed

* [x] Duplicate `allowUnfree` configuration reviewed.
* [x] Tailscale SSH firewall ownership consolidated.
* [x] AppArmor bot paths parameterized.
* [x] GitOps-related configuration coupling reduced.
* [x] CI notification configuration decoupled from unrelated feature flags.
* [x] Deployment-health configuration decoupled from GitOps option ownership.
* [x] GitLab Runner configuration decoupled from GitOps option ownership.

## Remaining Known Issue

| ID | Severity | Area              | Description                                                                                                        | Status |
| -- | -------- | ----------------- | ------------------------------------------------------------------------------------------------------------------ | ------ |
| 11 | LOW      | Nix configuration | `nix.settings.substituters` remains split between `system/nix.nix`, `caching/default.nix`, and `cache/default.nix` | Open   |

This remains acceptable while explicitly tracked, but should eventually be consolidated into one authoritative configuration path.

## Additional Consolidation Targets

The audit should continue checking for:

* duplicate resource limits
* duplicate package declarations
* duplicate firewall rules
* duplicate service configuration
* duplicate environment variables
* duplicate systemd settings
* duplicate observability configuration
* duplicate network configuration
* duplicate secret configuration

---

# 8. Phase 4 — Service Contracts

## Objective

Make runtime capabilities depend on stable service contracts rather than concrete implementations or shell-script coupling.

## Completed

The control plane has defined the following service contracts:

### `NotificationService`

Responsible for:

* alerts
* deployment results
* health alerts

### `BackupService`

Responsible for:

* triggering backups
* backup status
* snapshot listing
* latest snapshot
* latest run information

### `MetricsProvider`

Responsible for:

* metrics queries
* service status
* system metrics

### `HealthChecker`

Responsible for:

* system health
* service health
* network health
* disk health

### `PlatformService`

Responsible for:

* health
* status
* doctor
* rebuild
* rollback

## Implementations

Concrete implementations exist under:

```text
internal/services/impl/
```

including:

* `ResticBackup`
* `PrometheusMetrics`
* `SystemHealthChecker`
* `NixOSPlatform`
* `Notification`

## Registry

Service wiring is centralized through:

```text
internal/services/container.go
```

and the application entrypoint.

## Remaining

* [ ] Continue migrating consumers away from direct infrastructure access.
* [ ] Remove redundant implementations.
* [ ] Replace remaining shell-script service coupling with explicit interfaces where appropriate.
* [ ] Verify every service has a documented owner and lifecycle.
* [ ] Add contract-level tests for critical services.

---

# 9. Phase 5 — Consumer Migration

## Objective

Move consumers from implementation-specific dependencies toward declared contracts and domain boundaries.

## Completed

* [x] Major service boundaries identified.
* [x] Runtime service contracts established.
* [x] Service implementations separated from interfaces.
* [x] Several cross-domain dependencies decoupled.
* [x] Hardcoded hostname assumptions removed from production code.

## Completed Boundary Fixes

### CI notification

Previously coupled to:

```text
fleet.gitlabRunner.enable
```

Now uses its own configuration ownership.

### Deployment health

Previously coupled directly to:

```text
fleet.gitops
```

Now owns its required repository and branch configuration explicitly.

### GitLab Runner

Previously coupled directly to:

```text
fleet.gitops
```

Now owns its required repository and branch configuration explicitly.

### AppArmor

Hardcoded bot paths were replaced with configurable state/log directory variables.

### Firewall

Duplicate Tailscale SSH port ownership was removed.

## Remaining

* [ ] Identify remaining direct cross-domain imports.
* [ ] Replace implicit filesystem reads with explicit contracts where practical.
* [ ] Remove direct service-name assumptions where an API/contract is more appropriate.
* [ ] Remove unnecessary shell-to-shell coupling.
* [ ] Ensure all dependencies are represented in `architecture/dependencies.yaml`.

---

# 10. Phase 6 — Legacy Removal

## Objective

Remove architectural mechanisms that have been replaced by the target architecture.

## Historical Legacy Targets

The migration has identified:

* `notify.sh` embedding
* hardcoded hostnames
* direct GitOps state consumers
* duplicate configuration
* implicit service dependencies
* direct filesystem reads across domain boundaries
* duplicated ownership
* undocumented network dependencies
* legacy deployment-health coupling

## Completed

* [x] Hardcoded `prague` references removed from identified production files.
* [x] CI failure suppression removed.
* [x] Architecture false positives for standard external tools reduced.
* [x] Filesystem boundary exceptions documented.
* [x] GitOps ownership formalized.
* [x] Several direct option dependencies removed.

## Remaining

* [ ] Remove obsolete compatibility paths.
* [ ] Remove obsolete exceptions after successful migration.
* [ ] Remove legacy shell-based implementations once contract replacements are verified.
* [ ] Delete dead code identified during audits.
* [ ] Re-run architecture tests after each removal.

---

# 11. Phase 7 — Architecture Enforcement

## Objective

Make architectural regression detectable before deployment.

## Architecture Linter

The following checks are currently operational:

```text
✓ forbidden_imports
✓ circular_dependencies
✓ filesystem_boundaries
✓ duplicate_ownership
✓ declared_dependencies
✓ internal_api_boundaries
✓ service_state_ownership
```

### Current Result

```text
7 / 7 architecture checks PASS
```

## Enforcement Targets

The architecture enforcement system must continue to validate:

1. Domain validity
2. Dependency direction
3. Circular dependencies
4. Filesystem ownership
5. Configuration ownership
6. Exception validity
7. Forbidden cross-domain access
8. Duplicate ownership
9. Undeclared dependencies
10. Host/domain boundaries

## CI

Architecture validation is part of the repository verification process.

Both CI systems are configured for the relevant verification gates:

```text
GitLab CI
GitHub Actions
```

The goal is:

```text
Architecture violation
        ↓
Automated detection
        ↓
CI failure
        ↓
Change cannot safely proceed
```

---

# 12. Security Architecture Progress

Security work is considered part of architecture because security boundaries must remain consistent with domain and ownership boundaries.

## Completed

* [x] Hardcoded Grafana credentials removed.
* [x] SOPS-based secret management enforced.
* [x] `.gitignore` hardened.
* [x] Web UI attack surface reduced.
* [x] Nginx restricted to Tailscale access.
* [x] OTel exposure restricted to loopback.
* [x] Scanner/exporter public exposure removed.
* [x] `ivali-api` AppArmor profile added.
* [x] Web UI AppArmor confinement added.
* [x] AppArmor paths parameterized.
* [x] Tailscale SSH firewall ownership consolidated.

## Remaining

* [ ] Continue security architecture regression tests.
* [ ] Revalidate AppArmor profiles after service changes.
* [ ] Verify all secret consumers against declared ownership.
* [ ] Ensure no new public listeners are introduced without explicit architectural ownership.

---

# 13. Platform and Hardware Progress

These changes are implementation work supporting the architectural target and are tracked here because they affect host composition and operational behavior.

## Hardware

* [x] `hardware/` domain established.
* [x] USB power-management configuration added.

## Boot

* [x] TPM-related boot issues addressed.
* [x] Serial ports disabled where unnecessary.
* [x] Boot time significantly reduced.
* [x] GRUB adopted.
* [x] NixOS snowflake boot theme configured.

## Audio

* [x] ALSA mixer initialization addressed.
* [x] WirePlumber rules added for consistent ALC236 behavior.
* [x] Audio behavior verified against the current desktop configuration.

## Desktop

* [x] GNOME architecture documented.
* [x] Legacy XFCE documentation references removed.
* [x] GNOME Remote Desktop configuration verified.
* [x] Remote desktop firewall integration verified.
* [x] Remote desktop helper tooling verified.

---

# 14. Observability Progress

## Completed

* [x] Observability enabled on `prague`.
* [x] Observability documentation created.
* [x] Health observer dependencies validated.
* [x] Dashboard health information verified.
* [x] GitOps reconciler status added to dashboard.
* [x] Deployment health status added to dashboard.
* [x] Scrape-target validation added.
* [x] Blocky validation added.
* [x] Exit-node validation added.
* [x] CI registration completed for these checks.

## Architectural Rule

Observability is a **consumer of system state**, not the owner of state belonging to another domain.

Any future observability feature must therefore identify:

```text
Observed domain
      ↓
Contract / metric
      ↓
Observability consumer
```

rather than directly taking ownership of the observed domain's persistent state.

---

# 15. CI and Verification Progress

## Completed

* [x] GitLab CI architecture validation.
* [x] GitHub Actions architecture validation.
* [x] `golangci-lint` v2 integration.
* [x] Scrape-target check.
* [x] Blocky validation.
* [x] Exit-node validation.
* [x] CI failure suppression removed.
* [x] Architecture linter registered in verification.

## Current Required Verification

```text
Formatting
    ↓
Architecture tests
    ↓
Architecture linter
    ↓
Go tests / build / vet
    ↓
Shell validation
    ↓
Nix evaluation
    ↓
Integration verification
    ↓
Build
    ↓
Runtime health
```

---

# 16. TDD and Architecture Progress

Architectural changes follow the repository's TDD model.

## New Architectural Behavior

```text
Define invariant
      ↓
Write test
      ↓
Run test
      ↓
RED
      ↓
Implement architecture
      ↓
GREEN
      ↓
Refactor
      ↓
Run complete verification
```

## Architectural Bug Fix

```text
Reproduce violation
      ↓
Write regression test
      ↓
RED
      ↓
Fix architecture
      ↓
GREEN
      ↓
Refactor
      ↓
Run complete verification
```

Architecture rules themselves should therefore be treated as executable behavior, not merely documentation.

---

# 17. Verification Status

The following verification has been completed according to the latest recorded validation run:

| Gate                     | Status |
| ------------------------ | ------ |
| Nix formatting           | PASS   |
| Go build                 | PASS   |
| Go vet                   | PASS   |
| Go tests                 | PASS   |
| Shell syntax             | PASS   |
| `prague` Nix evaluation  | PASS   |
| `testvm` Nix evaluation  | PASS   |
| `tuscany` Nix evaluation | PASS   |
| Architecture linter      | PASS   |
| Scrape-target validation | PASS   |
| Blocky validation        | PASS   |
| Exit-node validation     | PASS   |
| `golangci-lint` v2       | PASS   |

### Architecture Linter

```text
7 / 7 checks PASS
```

---

# 18. Current Open Work

The remaining work should be tracked by architectural outcome rather than by historical session number.

## HIGH

No currently recorded unresolved HIGH-severity architecture violations.

## MEDIUM

No currently recorded unresolved MEDIUM-severity violations from the previous audit.

## LOW

### LOW-11 — Substituter configuration consolidation

Current configuration is distributed across:

```text
system/nix.nix
caching/default.nix
cache/default.nix
```

### Required outcome

Establish one authoritative configuration path for substituters.

### Status

```text
OPEN — ACCEPTABLE
```

It remains tracked because duplicate ownership increases the risk of configuration drift.

---

# 19. Historical Work Completed

The earlier session-based architecture program produced the following major outcomes:

* [x] Full architectural audit.
* [x] Dependency graph.
* [x] Domain design.
* [x] State ownership model.
* [x] Architecture manifests.
* [x] Architecture linter.
* [x] Architecture tests.
* [x] CI integration.
* [x] High-severity violation remediation.
* [x] Medium-severity violation remediation.
* [x] Service contracts.
* [x] Service implementations.
* [x] Service registry.
* [x] Security hardening.
* [x] Observability integration.
* [x] Hardware domain.
* [x] Boot improvements.
* [x] Audio improvements.
* [x] GNOME documentation alignment.
* [x] GNOME Remote Desktop integration.
* [x] CI security and infrastructure checks.
* [x] Documentation alignment.

Historical phase numbers remain useful as project history, but **current architectural status is determined by the phase model in this document and the evidence in `ARCHITECTURE_AUDIT.md`.**

---

# 20. Next Architectural Actions

The next work should proceed in this order:

### 1. Re-audit

Run the current architecture audit against the repository as it exists now.

Confirm:

* domains
* dependencies
* state ownership
* filesystem ownership
* configuration ownership
* service contracts
* exceptions
* runtime services

### 2. Resolve LOW-11

Consolidate:

```text
nix.settings.substituters
```

into a single authoritative configuration path.

### 3. Re-run architecture enforcement

Run:

```text
architecture tests
architecture linter
Go tests
Go build
Go vet
golangci-lint
Nix evaluation
shell validation
```

### 4. Revalidate exceptions

Review every entry in:

```text
architecture/exceptions.yaml
```

and classify it as:

```text
VALID
MIGRATE
REMOVE
EXPIRED
```

### 5. Continue consumer migration

Prioritize:

```text
direct filesystem access
hardcoded service dependencies
implicit systemd dependencies
shell-script coupling
cross-domain imports
duplicate configuration
```

### 6. Remove obsolete architecture

Once replacements are verified:

```text
legacy implementation
        ↓
migration complete
        ↓
regression tests
        ↓
remove legacy path
        ↓
remove exception
        ↓
architecture linter
        ↓
CI verification
```

### 7. Establish continuous enforcement

No architectural migration should be considered complete until:

```text
Implementation
     +
Tests
     +
Architecture manifest
     +
Architecture linter
     +
CI enforcement
     +
Documentation
```

all agree.

---

# 21. Deployment Gate

Architecture work is **not complete merely because tests pass**.

Before applying a production host change, the repository must have:

* [x] Architecture tests passing.
* [x] Architecture linter passing.
* [x] Go tests passing.
* [x] Go build passing.
* [x] Nix evaluation passing.
* [x] Shell validation passing.
* [x] Security checks passing.
* [ ] Current working tree reviewed.
* [ ] `ivali flow` used for the Git lifecycle.
* [ ] Deployment health verified after activation.
* [ ] Rollback path available.

The deployment sequence remains:

```text
Change
  ↓
TDD
  ↓
RED
  ↓
Implementation
  ↓
GREEN
  ↓
Refactor
  ↓
Architecture validation
  ↓
CI
  ↓
Merge through ivali flow
  ↓
GitOps reconciliation
  ↓
Generation switch
  ↓
Health validation
  ↓
Rollback if unhealthy
```

Direct Git lifecycle bypasses remain prohibited.

---

# 22. Definition of Architectural Completion

The architecture migration is complete when:

* every domain has a clear owner;
* every dependency is declared;
* every persistent state path has one owner;
* every configuration concern has one authoritative source;
* service boundaries are contract-based;
* cross-domain dependencies are explicit;
* exceptions are minimal and justified;
* legacy implementations have been removed;
* architecture tests cover the important invariants;
* the architecture linter passes;
* CI prevents architectural regression;
* deployment and recovery paths are independently understandable;
* operational documentation reflects the actual repository;
* the current audit contains no unexplained architectural violations.

The final state should be:

```text
ARCHITECTURE.md
      │
      │ defines target
      ▼
Architecture manifests
      │
      │ define machine-readable rules
      ▼
Architecture tests + linter
      │
      │ enforce invariants
      ▼
CI
      │
      │ prevents regression
      ▼
Implementation
      │
      │ produces runtime system
      ▼
ARCHITECTURE_AUDIT.md
      │
      │ records actual conformance
      ▼
ARCHITECTURE_PROGRESS.md
      │
      │ tracks migration
      └───────────────┐
                      ▼
                 Next action
```

---

# 23. Document Relationship

These documents intentionally have different responsibilities:

| Document                         | Responsibility                            |
| -------------------------------- | ----------------------------------------- |
| `AGENTS.md`                      | AI operating contract                     |
| `ENGINEERING.md`                 | Engineering standards                     |
| `ARCHITECTURE.md`                | **Target architecture**                   |
| `ARCHITECTURE_AUDIT.md`          | **Current architectural conformance**     |
| `ARCHITECTURE_PROGRESS.md`       | **Migration and implementation progress** |
| `architecture/domains.yaml`      | Domain declarations                       |
| `architecture/dependencies.yaml` | Dependency declarations                   |
| `architecture/exceptions.yaml`   | Approved exceptions                       |
| Architecture tests/linter        | Executable enforcement                    |
| `IVALi_FLOW.md`                  | Git lifecycle                             |
| `CONTEXT_HANDOFF.md`             | Session continuity                        |

The separation is intentional:

```text
ARCHITECTURE.md
"What should the system look like?"

ARCHITECTURE_AUDIT.md
"What does the repository actually look like?"

ARCHITECTURE_PROGRESS.md
"How do we move from the current state to the target state?"
```

This separation prevents the architecture, audit, and migration documents from becoming contradictory sources of truth.

---

# 24. Current Status

```text
Architecture definition       ████████████████████  Complete
Machine-readable architecture ████████████████████  Complete
Architecture testing          ████████████████████  Operational
Architecture linting          ████████████████████  Operational
CI enforcement                ████████████████████  Operational
State ownership               ███████████████████░  Substantially complete
Service contracts             ███████████████████░  Substantially complete
Consumer migration            ███████████████░░░░░  In progress
Configuration consolidation   ████████████████░░░░  In progress
Legacy removal                ██████████████░░░░░░  In progress
Continuous re-audit           █████████████████░░░  Ongoing
```

**Overall architectural state:**

> **The repository has moved from documented architecture to machine-readable, tested, and CI-enforced architecture. The remaining work is controlled migration and consolidation, not architectural discovery.**

