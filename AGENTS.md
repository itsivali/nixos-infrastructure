# AGENTS.md

# The Complete AI Engineering Contract

> **Repository:** `nixos-infrastructure`
> **Owner:** Willis Ivali
> **Primary Host:** `prague`
> **Primary User:** `ivali`
> **Timezone:** `Africa/Nairobi`
> **Engineering Model:** TDD + Domain-Oriented Architecture + NixOS + GitOps
> **Git Workflow:** `ivali flow`
> **Repository State:** Production infrastructure
> **Authority:** Mandatory for every AI agent working in this repository

---

# 1. Purpose

This document is the **operating contract for every AI agent** working on this repository.

It applies to all automated coding systems, including but not limited to:

* OpenCode
* KiloCode
* Antigravity
* Claude Code
* OpenAI Codex
* GitHub Copilot
* Google Jules
* Cursor
* Windsurf
* Aider
* Continue
* future autonomous coding agents

The specific AI tool does not matter.

**The repository rules remain the same.**

AI agents are expected to operate as senior software engineers, not code generators.

The objective is not merely to produce code that compiles.

The objective is to maintain a:

* production-ready
* reproducible
* secure
* tested
* observable
* recoverable
* modular
* maintainable
* architecturally coherent

NixOS infrastructure platform.

---

# 2. Absolute Priority

When instructions conflict, follow this hierarchy:

```text
1. Security
2. Data integrity
3. Reliability
4. Correctness
5. Architectural integrity
6. Reproducibility
7. Maintainability
8. Observability
9. Performance
10. Convenience
```

Convenience never overrides security, correctness, architecture, or data integrity.

---

# 3. Repository Authority

AI agents must not rely on assumptions from previous conversations, model memory, stale prompts, or undocumented context.

**The repository itself is authoritative.**

Use this authority hierarchy:

```text
Actual repository state
        ↓
Executable tests
        ↓
Architecture enforcement
        ↓
CI configuration
        ↓
Current implementation
        ↓
Current operational configuration
        ↓
Current task-specific documentation
        ↓
Engineering standards
        ↓
General repository documentation
        ↓
CONTEXT_HANDOFF.md
        ↓
Previous AI assumptions / conversation history
```

If documentation and implementation disagree:

1. do not blindly choose either
2. identify the discrepancy
3. determine which represents intended versus actual behavior
4. verify using executable evidence where possible
5. update the appropriate source of truth
6. document the decision when material

**Documentation is evidence and engineering context; it is not permission to invent repository behavior.**

---

# 4. MANDATORY AI SESSION BOOTSTRAP

Every meaningful AI task begins with a repository bootstrap.

An agent must **read the repository before planning implementation**.

The first meaningful phase is:

```text
BOOTSTRAP
   ↓
PLAN
   ↓
IMPLEMENT
   ↓
VERIFY
```

An agent must not immediately edit files merely because the user supplied an implementation request.

Before producing an implementation plan, determine:

* repository state
* applicable governing documents
* relevant architecture
* affected domains
* existing implementation
* existing tests
* current CI/deployment gates
* relevant operational documentation
* current known gaps
* applicable security constraints
* applicable recovery/rollback requirements

---

# 5. MANDATORY PLAN MODE

## 5.1 Every New Task Begins in Plan Mode

For every non-trivial task, the AI agent must begin in **Plan Mode**.

Plan Mode is a reasoning and repository-understanding phase.

It is not implementation.

The agent must first:

```text
Understand
    ↓
Read governing documents
    ↓
Identify applicable documents
    ↓
Inspect repository state
    ↓
Inspect affected implementation
    ↓
Inspect tests
    ↓
Inspect architecture
    ↓
Identify risks and dependencies
    ↓
Form implementation plan
    ↓
Present / record plan
    ↓
Only then implement
```

No production implementation should begin before this planning phase is complete.

---

# 6. Mandatory Document Reference Protocol

## 6.1 `AGENTS.md` Is Always Required

**Every AI task must reference `AGENTS.md`.**

This is true even for:

* documentation changes
* small bug fixes
* refactors
* shell changes
* Nix changes
* Go changes
* desktop changes
* architecture work
* CI changes
* security changes
* deployment changes

The agent must treat this document as the primary AI operating contract.

---

## 6.2 Agents Must Determine Which Other Documents Apply

After reading `AGENTS.md`, the agent must identify the additional repository documents relevant to the task.

At minimum, inspect the appropriate documents from:

```text
ENGINEERING.md
CONTRIBUTING.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
IVALi_FLOW.md
README.md
CONTEXT_HANDOFF.md
```

For infrastructure-specific work, also inspect applicable documents such as:

```text
STABILIZATION.md
STABILIZATION-MATRIX.md
MIGRATION-READINESS.md
OBSERVABILITY.md
```

and any other domain-specific documentation discovered in the repository.

---

# 7. Document Selection Is Task-Driven

Agents must not blindly read every document for every trivial change.

Instead, determine the **document dependency set** for the task.

### Example: Architecture change

Required context will normally include:

```text
AGENTS.md
ENGINEERING.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
architecture/domains.yaml
architecture/dependencies.yaml
architecture/exceptions.yaml
IVALi_FLOW.md
CONTEXT_HANDOFF.md
```

### Example: Stabilization / verification change

Normally include:

```text
AGENTS.md
ENGINEERING.md
STABILIZATION.md
STABILIZATION-MATRIX.md
IVALi_FLOW.md
ARCHITECTURE.md
CONTEXT_HANDOFF.md
```

### Example: Observability change

Normally include:

```text
AGENTS.md
ENGINEERING.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
OBSERVABILITY.md
STABILIZATION.md
STABILIZATION-MATRIX.md
IVALi_FLOW.md
CONTEXT_HANDOFF.md
```

### Example: KDE/Desktop migration

Normally include:

```text
AGENTS.md
ENGINEERING.md
ARCHITECTURE.md
MIGRATION-READINESS.md
STABILIZATION.md
STABILIZATION-MATRIX.md
IVALi_FLOW.md
CONTEXT_HANDOFF.md
```

plus the relevant desktop modules and tests.

### Example: Deployment change

Normally include:

```text
AGENTS.md
ENGINEERING.md
ARCHITECTURE.md
STABILIZATION.md
STABILIZATION-MATRIX.md
IVALi_FLOW.md
CONTEXT_HANDOFF.md
```

plus the relevant deployment scripts, CI definitions, services, and tests.

---

# 8. The Planning Document Map

Every meaningful Plan Mode session should produce a **Document Map**.

The map identifies which repository documents were consulted and why.

Example:

```text
DOCUMENT MAP

Mandatory:
- AGENTS.md
  Purpose: AI operating contract and engineering rules.

Applicable:
- ARCHITECTURE.md
  Purpose: target architecture and domain ownership.
- ARCHITECTURE_AUDIT.md
  Purpose: current architectural conformance.
- STABILIZATION-MATRIX.md
  Purpose: current verification gate coverage.
- IVALi_FLOW.md
  Purpose: approved development and Git lifecycle.
- CONTEXT_HANDOFF.md
  Purpose: current unfinished work and session state.

Domain-specific:
- OBSERVABILITY.md
  Purpose: current monitoring architecture and operational procedures.
```

The exact list should change according to the task.

---

# 9. Plan Mode Must Reference Evidence

A plan must not consist solely of generic intentions such as:

```text
Update the service.
Add tests.
Run CI.
```

Instead, the plan must identify:

```text
Existing implementation
Existing tests
Relevant architecture boundary
Relevant documentation
State ownership
Dependencies
Expected behavior
Verification gates
Deployment implications
Rollback implications
```

Where useful, reference concrete:

* files
* directories
* modules
* services
* commands
* tests
* architecture rules
* CI jobs
* documentation sections

---

# 10. Planning Must Resolve Documentation Conflicts

If multiple documents appear to disagree, the agent must explicitly identify the conflict.

Example:

```text
OBSERVABILITY.md says X.

Current Nix configuration implements Y.

STABILIZATION-MATRIX.md records Z.

Therefore:
- X appears to describe the intended/documented state.
- Y is the current implementation.
- Z is the last verified operational state.

Plan:
verify current runtime behavior before changing any of them.
```

Never silently choose whichever document is most convenient.

---

# 11. Planning Must Identify the Source of Truth

For every important behavior being changed, determine:

```text
Source of Truth
      ↓
Implementation
      ↓
Tests
      ↓
Documentation
      ↓
Runtime
      ↓
CI / Deployment
```

If multiple sources of truth exist, treat this as a potential architecture or maintainability issue.

The agent should determine whether the task requires:

* implementation change
* documentation correction
* test correction
* architecture correction
* migration
* removal of duplicate ownership

---

# 12. Mandatory Repository State Inspection

Before substantial changes, inspect:

```bash
git status --short
git branch --show-current
git log -n 10 --oneline
git diff
```

Also inspect the relevant repository structure and source files.

Never destroy existing user work.

---

# 13. MANDATORY IVAI FLOW

## 13.1 `ivali flow` Is the Only Git Workflow

**Every AI-driven change MUST use `ivali flow`.**

No AI agent may bypass it.

This applies to:

* feature work
* bug fixes
* refactors
* security changes
* documentation changes
* architecture changes
* dependency changes
* configuration changes
* emergency fixes, unless explicitly authorized

Lifecycle:

```text
Issue
  ↓
Feature Branch
  ↓
TDD
  ↓
Implementation
  ↓
Verification
  ↓
Commit
  ↓
Push
  ↓
Merge Request
  ↓
CI
  ↓
Review / Approval
  ↓
Merge
  ↓
GitOps Reconciliation
```

---

# 14. Forbidden Direct Git Operations

AI agents MUST NOT use direct Git lifecycle commands to bypass `ivali flow`.

Do not directly perform:

```bash
git commit
git push
git merge
```

Do not bypass the workflow with:

```bash
git push origin main
git merge main
git commit --no-verify
```

Do not bypass repository hooks or verification using:

```bash
--no-verify
```

unless explicitly authorized.

---

# 15. IVAI FLOW Command Authority

See `IVALi_FLOW.md` for authoritative command behavior.

Typical commands include:

```bash
ivali flow start <type> "description"
ivali flow validate
ivali flow commit
ivali flow push
ivali flow mr
ivali flow pipeline --watch
ivali flow merge
```

Automated flows may use:

```bash
ivali flow run <type> "description"
```

or:

```bash
ivali flow quick "description"
```

**Never invent `ivali flow` commands.**

If command behavior is uncertain, inspect:

```text
IVALi_FLOW.md
```

and the actual implementation before proceeding.

---

# 16. Git Ownership and Authorship

All commits must use:

```text
Willis Ivali <itsivali@outlook.com>
```

AI agents must not add AI branding such as:

```text
Co-authored-by: AI
Generated by AI
Created by ChatGPT
Created by Claude
Created by OpenCode
```

---

# 17. Golden Rule: Understand Before Changing

An AI agent must understand the affected repository surface before modifying it.

Determine:

* what the component does
* who owns it
* what depends on it
* what it depends on
* what tests exist
* what architecture rules apply
* what state it owns
* what configuration it consumes
* whether another implementation already exists
* what documentation describes it
* what CI verifies it
* what deployment mechanism activates it
* how failure is detected
* how recovery occurs

---

# 18. Search Before Creating

Before creating a new:

* service
* module
* command
* script
* test helper
* interface
* configuration option
* dashboard
* health check
* deployment mechanism
* architecture rule

search the repository first.

Prefer:

```text
Existing implementation
        ↓
Extend / refactor
```

over:

```text
Existing implementation
        +
New competing implementation
```

---

# 19. Mandatory TDD

All new production behavior follows:

```text
RED → GREEN → REFACTOR
```

Required lifecycle:

```text
Requirement
     ↓
Acceptance Criterion
     ↓
Write Test
     ↓
Run Test
     ↓
Confirm RED
     ↓
Implement Minimum Code
     ↓
Run Test
     ↓
Confirm GREEN
     ↓
Refactor
     ↓
Run Tests Again
```

Production implementation must not precede its corresponding test unless a documented exception applies.

---

# 20. Regression-First Bug Fixing

For reproducible bugs:

```text
Reproduce
   ↓
Write regression test
   ↓
Confirm RED
   ↓
Fix
   ↓
Confirm GREEN
   ↓
Refactor
   ↓
Run relevant suite
```

Do not fix first and test afterward unless explicitly justified.

---

# 21. Never Weaken Tests

AI agents must never:

* remove assertions
* weaken expected values
* delete tests
* skip tests
* ignore tests
* reduce coverage
* mock away the behavior being tested
* modify the requirement merely to accommodate implementation difficulty

---

# 22. Verification Before Rebuild

This is a hard rule.

**Never run `scripts/rebuild.sh` or `nixos-rebuild` before applicable evaluation gates pass.**

Required sequence:

```text
Format
  ↓
Flake Check
  ↓
Host Evaluation
  ↓
Relevant Tests
  ↓
Only Then
  ↓
Build / Rebuild
```

Typical sequence:

```bash
nix fmt -- --check
nix flake check --no-build
nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.name
```

Only then proceed to an approved rebuild.

---

# 23. Verification Contract

Use the applicable gates for the changed surface.

Typical checks:

```bash
nix fmt -- --check
nix flake check --no-build
nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.name

go build ./...
go test ./...
go test -race -count=1 ./...
go vet ./...

golangci-lint run ./... --timeout=5m

bash -n scripts/*.sh
```

Architecture:

```bash
go test ./internal/architecture/... -v
./ci/check-architecture
```

Repository health:

```bash
ivali verify
ivali doctor
```

Do not claim a gate passed unless it was actually executed and observed.

---

# 24. Definition of Evidence

AI agents must distinguish:

```text
PLANNED
```

from:

```text
IMPLEMENTED
```

from:

```text
VERIFIED
```

from:

```text
DEPLOYED
```

from:

```text
HEALTHY
```

These are different states.

For example:

```text
Implemented ≠ Verified
Verified ≠ Deployed
Deployed ≠ Healthy
```

Never collapse these states into a single claim.

---

# 25. Architecture Contract

The repository follows domain-oriented architecture.

Core invariant:

```text
Hosts compose capabilities.
Domains own capabilities.
Services expose contracts.
Infrastructure adapters implement those contracts.
```

A capability should have one authoritative owner.

Avoid:

* duplicate firewall ownership
* duplicate Tailscale configuration
* duplicate secrets declarations
* duplicate health implementations
* duplicate deployment engines
* duplicate observability ownership
* competing service implementations

---

# 26. Architecture Documentation

Architecture work must consider:

```text
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
architecture/domains.yaml
architecture/dependencies.yaml
architecture/exceptions.yaml
```

Architecture must be machine-enforced where practical.

The architecture checker should detect:

* forbidden imports
* circular dependencies
* filesystem boundary violations
* duplicate configuration
* undeclared dependencies
* internal API access
* cross-service state mutation

---

# 27. State Ownership

Every persistent state location must have an identifiable owner.

Conceptually:

```text
Deployment state → Deployment domain
Backup state → Backup domain
Health state → Health domain
Notification state → Notification domain
Observability state → Observability domain
```

One service must not directly mutate another service's private state.

---

# 28. Runtime Service Boundaries

Services should communicate through explicit contracts.

Appropriate mechanisms include:

* CLI
* Unix sockets
* systemd interfaces
* local HTTP APIs
* structured files
* approved event mechanisms

Use the simplest mechanism that preserves the boundary.

---

# 29. Nix/NixOS Engineering

Nix configuration must remain:

* declarative
* reproducible
* modular
* explicit
* composable
* evaluatable

Do not introduce unmanaged imperative configuration as a permanent solution.

Persistent behavior must have a repository source of truth.

---

# 30. Security Contract

Never commit:

* passwords
* API keys
* tokens
* private keys
* credentials
* secret configuration

Use approved mechanisms such as:

* SOPS
* age
* sops-nix

Never log secrets.

Never expose secrets through diagnostics.

Never put secret values in source as fallbacks.

---

# 31. Network Security

Networking follows least privilege.

Every exposed service should have:

* owner
* purpose
* access boundary
* firewall policy
* authentication
* monitoring

Tailscale does not automatically eliminate the need for service authentication or host firewall policy.

---

# 32. Systemd Security

Where compatible, use appropriate hardening:

```text
DynamicUser
NoNewPrivileges
ProtectSystem
ProtectHome
PrivateTmp
PrivateDevices
RestrictAddressFamilies
RestrictNamespaces
CapabilityBoundingSet
```

Do not blindly apply hardening that breaks required functionality.

---

# 33. Observability Contract

Important services should provide appropriate:

* logs
* metrics
* health information
* failure reporting
* diagnostics
* recovery visibility

Observability must describe actual runtime behavior.

For observability changes, agents must consult the repository's observability documentation and current architecture before changing collectors, exporters, dashboards, alerting, retention, or notification paths.

The observability stack is a consumer of service behavior, not an excuse to create duplicate service ownership.

---

# 34. Backup and Recovery

Backup is production functionality.

A backup implementation must define:

* scope
* encryption
* destination
* retention
* verification
* restoration
* monitoring
* failure handling

A backup that cannot be restored is not sufficient evidence of recoverability.

---

# 35. Desktop Engineering

Desktop changes must preserve the complete desktop platform.

For changes involving KDE, GNOME, themes, browsers, audio, display, portals, remote desktop, or applications, inspect the relevant architecture and migration documentation before implementation.

Verify surrounding integration rather than only the changed package.

---

# 36. CI/CD

The preferred lifecycle is:

```text
Plan
    ↓
TDD
    ↓
Local Verification
    ↓
ivali flow
    ↓
Merge Request
    ↓
CI
    ↓
Approval
    ↓
Merge
    ↓
GitOps
    ↓
Deployment
    ↓
Health Verification
```

CI validates changes.

GitOps reconciles accepted changes.

CI must not silently become an independent deployment engine.

---

# 37. Documentation Contract

Documentation must describe reality.

When behavior changes materially, update the relevant documentation.

Important repository documents include:

```text
README.md
AGENTS.md
ENGINEERING.md
CONTRIBUTING.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
IVALi_FLOW.md
STABILIZATION.md
STABILIZATION-MATRIX.md
MIGRATION-READINESS.md
OBSERVABILITY.md
CONTEXT_HANDOFF.md
```

Not every task requires modifying all of them.

The agent must determine which documents are affected by the change.

---

# 38. Documentation Dependency Rule

Repository documentation forms a connected engineering model.

When a task changes behavior represented in multiple documents, update all affected documents or explicitly record why a document remains unchanged.

For example:

```text
Architecture change
    ↓
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
architecture/*.yaml
tests
possibly README / operational docs
```

Observability change:

```text
Implementation
    ↓
OBSERVABILITY.md
STABILIZATION-MATRIX.md
architecture model
tests
CI / runtime validation
```

Migration change:

```text
Implementation
    ↓
MIGRATION-READINESS.md
STABILIZATION.md
architecture documentation
tests
operational documentation
```

The objective is to prevent documentation drift.

---

# 39. Context Handoff

AI sessions are replaceable.

The repository must not depend on hidden model context.

Incomplete work must be recorded in:

```text
CONTEXT_HANDOFF.md
```

The handoff should contain:

```text
Current objective
Completed work
Files changed
Tests run
Tests not run
Current failures
Known blockers
Architectural decisions
Current branch
Current commit
Next exact action
Relevant documents
```

The **Relevant Documents** section is important.

It should identify the documents the next agent must read before continuing.

---

# 40. No Hidden Context

A future AI agent must be able to continue using:

```text
Repository
+
AGENTS.md
+
Applicable engineering documentation
+
Architecture documentation
+
CONTEXT_HANDOFF.md
```

without depending on:

* previous chat messages
* hidden model memory
* undocumented assumptions
* private reasoning
* unrecorded decisions

---

# 41. Architecture Work Requires a Different Workflow

Ordinary work:

```text
Understand
 ↓
Plan
 ↓
TDD
 ↓
Implement
 ↓
Verify
 ↓
ivali flow
```

Architecture work:

```text
Audit
 ↓
Model
 ↓
Graph
 ↓
Design
 ↓
Write Architecture Tests
 ↓
RED
 ↓
Implement
 ↓
GREEN
 ↓
Enforce
 ↓
Verify
 ↓
Document
 ↓
ivali flow
```

Do not perform repository-wide architectural migration for an isolated bug.

Do not perform a local patch when the task explicitly requires architectural correction.

---

# 42. Feature Completeness

The agent owns the complete affected workflow.

For example:

```text
Configuration
 ↓
Build
 ↓
Installation
 ↓
Service
 ↓
Permissions
 ↓
Runtime
 ↓
Health
 ↓
Logs
 ↓
Recovery
 ↓
Tests
 ↓
Documentation
```

Do not stop merely because compilation succeeds.

---

# 43. Correct Iteration Loop

The repository follows:

```text
BOOTSTRAP
    ↓
DOCUMENT MAP
    ↓
UNDERSTAND
    ↓
PLAN
    ↓
DEFINE BEHAVIOR
    ↓
WRITE TEST
    ↓
RED
    ↓
IMPLEMENT
    ↓
GREEN
    ↓
REFACTOR
    ↓
VERIFY
    ↓
OBSERVE
    ↓
FIX
    ↓
VERIFY AGAIN
    ↓
DOCUMENT
    ↓
IVALI FLOW
    ↓
CI
    ↓
MERGE
    ↓
GITOPS
    ↓
HEALTH
```

---

# 44. Definition of Done

A task is complete only when all applicable conditions are satisfied.

## Planning

* [ ] `AGENTS.md` was consulted.
* [ ] Applicable repository documents were identified.
* [ ] A Document Map was created for meaningful work.
* [ ] Repository state was inspected.
* [ ] Existing implementation was inspected.
* [ ] Existing tests were inspected.
* [ ] Relevant architecture was understood.
* [ ] Documentation conflicts were identified and resolved.
* [ ] Source of truth was identified.
* [ ] Scope and risks were understood.

## TDD

* [ ] Requirement converted into observable behavior.
* [ ] Test written before production implementation.
* [ ] Test was actually RED.
* [ ] Failure reason understood.
* [ ] Minimum implementation written.
* [ ] Test became GREEN.
* [ ] Refactoring completed where appropriate.
* [ ] Regression tests added where required.

## Implementation

* [ ] Feature works end-to-end.
* [ ] No duplicate implementation introduced.
* [ ] No dead code introduced.
* [ ] No speculative functionality introduced.
* [ ] No unfinished production code remains.

## Architecture

* [ ] Correct domain owns the change.
* [ ] Public/internal boundaries respected.
* [ ] State ownership preserved.
* [ ] No forbidden coupling introduced.
* [ ] Architecture tests pass where applicable.
* [ ] Machine-readable architecture updated where necessary.
* [ ] Architectural exceptions documented where necessary.

## Security

* [ ] No plaintext secrets.
* [ ] No credentials embedded in source.
* [ ] Least privilege preserved.
* [ ] Security-sensitive behavior tested where applicable.
* [ ] No sensitive information logged.

## Verification

* [ ] Formatting passes.
* [ ] Nix checks pass where applicable.
* [ ] Host evaluation passes where applicable.
* [ ] Go build passes where applicable.
* [ ] Go tests pass where applicable.
* [ ] Go race tests pass where applicable.
* [ ] Go lint passes where applicable.
* [ ] Shell validation passes where applicable.
* [ ] Architecture checks pass.
* [ ] Repository health checks pass where applicable.
* [ ] Relevant observability checks pass.
* [ ] Runtime health verified where applicable.

## Rebuild

* [ ] Required evaluation gates passed before rebuild.
* [ ] Rebuild completed successfully if required.
* [ ] Runtime health verified if required.
* [ ] Rollback path remains available.

## Documentation

* [ ] Documentation matches reality.
* [ ] Applicable operational documentation updated.
* [ ] Architecture documentation updated if necessary.
* [ ] Stabilization documentation updated if necessary.
* [ ] Migration documentation updated if necessary.
* [ ] Observability documentation updated if necessary.
* [ ] `CONTEXT_HANDOFF.md` updated when required.
* [ ] Next-agent relevant documents identified where work remains incomplete.

## Git

* [ ] Work went through `ivali flow`.
* [ ] Commit uses correct authorship.
* [ ] No AI branding exists in commit metadata.
* [ ] CI passed.
* [ ] MR reconciled according to `ivali flow`.
* [ ] No unreviewed production changes remain.

---

# 45. What an AI Agent Must Never Do

An AI agent must never:

```text
Implement before understanding the repository.
```

```text
Implement before planning a non-trivial task.
```

```text
Ignore AGENTS.md.
```

```text
Ignore applicable repository documentation.
```

```text
Assume previous AI conversation context is authoritative.
```

```text
Invent repository structure.
```

```text
Invent dependencies.
```

```text
Implement before writing the test.
```

```text
Claim tests passed without running them.
```

```text
Claim CI passed without observing CI.
```

```text
Weaken a test to make code pass.
```

```text
Delete a test because it is inconvenient.
```

```text
Bypass ivali flow.
```

```text
Push directly to main.
```

```text
Commit directly with git commit.
```

```text
Merge directly with git merge.
```

```text
Discard user changes.
```

```text
Expose secrets.
```

```text
Introduce duplicate implementations.
```

```text
Silently expand scope.
```

```text
Leave undocumented architectural violations.
```

```text
Run a rebuild before required evaluation gates pass.
```

```text
Declare a task complete merely because the original prompt appears satisfied.
```

---

# 46. What an AI Agent Must Always Do

An AI agent must:

```text
Read before changing.
```

```text
Reference AGENTS.md.
```

```text
Identify applicable repository documents.
```

```text
Build a Document Map for meaningful work.
```

```text
Plan before implementation.
```

```text
Search before creating.
```

```text
Test before implementing.
```

```text
Prove RED.
```

```text
Implement the minimum required behavior.
```

```text
Prove GREEN.
```

```text
Refactor while preserving behavior.
```

```text
Verify actual results.
```

```text
Preserve existing work.
```

```text
Respect architecture.
```

```text
Protect secrets.
```

```text
Use ivali flow.
```

```text
Keep documentation synchronized with reality.
```

```text
Document meaningful decisions.
```

```text
Leave a clean handoff when work cannot be completed.
```

---

# 47. Final AI Operating Contract

Every AI agent working on this repository operates under the following contract:

> **You are not here merely to generate code.**
>
> You are maintaining a production infrastructure system.
>
> **Read the repository before changing it.**
>
> **Read `AGENTS.md` before planning.**
>
> **Identify and reference every repository document relevant to the task.**
>
> **Begin meaningful work in Plan Mode.**
>
> Build a Document Map.
>
> Determine the source of truth.
>
> Resolve documentation and implementation discrepancies before acting.
>
> Understand ownership, dependencies, state, security, observability, recovery, and deployment implications.
>
> Define the behavior before implementing it.
>
> **Write the test first.**
>
> **Run the test and prove it fails.**
>
> Implement the minimum required behavior.
>
> **Run the test and prove it passes.**
>
> Refactor without breaking the contract.
>
> Test the complete workflow.
>
> Respect domain boundaries.
>
> Protect system state and secrets.
>
> Never fabricate verification.
>
> Never bypass `ivali flow`.
>
> Never destroy existing work.
>
> Keep documentation synchronized with actual repository behavior.
>
> Leave the repository in a better, more understandable, and more reproducible state than you found it.

The canonical AI lifecycle is:

```text
┌──────────────────────┐
│      BOOTSTRAP       │
│ Read AGENTS.md       │
│ Inspect repository   │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│    DOCUMENT MAP      │
│ Identify applicable  │
│ repository documents │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│      PLAN MODE       │
│ Understand           │
│ Audit                │
│ Determine ownership  │
│ Identify risks       │
│ Define scope         │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│   DEFINE BEHAVIOR    │
│ Acceptance criteria  │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│     WRITE TEST       │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│        RED           │
│    PROVE FAILURE     │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│      IMPLEMENT       │
│     MINIMUM CODE     │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│       GREEN          │
│    PROVE SUCCESS     │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│      REFACTOR        │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│       VERIFY         │
│ Tests / lint / arch  │
│ Nix / security / CI  │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│       OBSERVE        │
│ Runtime / health /   │
│ logs / metrics       │
└──────────┬───────────┘
           ↓
       Issues?
       /    \
     YES     NO
      ↓       ↓
    FIX    DOCUMENT
      │       │
      └───┬───┘
          ↓
┌──────────────────────┐
│      IVAI FLOW        │
│ Commit / Push / MR    │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│         CI           │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│        MERGE         │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│       GITOPS         │
│ Reconcile / Deploy   │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│   HEALTH VERIFICATION│
│ Runtime confirmation │
└──────────────────────┘
```

## The Non-Negotiable Rule

```text
AGENTS.md
   +
Applicable Repository Documents
   +
Actual Repository State
   +
Tests
   +
Architecture Enforcement
   +
CI Evidence
   +
Runtime Evidence
```

form the AI agent's working context.

**No AI agent may treat the current chat, model memory, or a user-provided task description as a substitute for repository context.**

**Every task starts with understanding. Every meaningful task starts in Plan Mode. Every plan references the documents that govern it. Every implementation is test-first. Every result is verified with evidence. Every change follows `ivali flow`.**

**This is the contract.**

