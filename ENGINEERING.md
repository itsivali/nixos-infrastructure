# IVALI Engineering Standards

> **Repository:** `nixos-infrastructure`
> **Owner:** Willis Ivali
> **Primary Host:** `prague`
> **Primary User:** `ivali`
> **Timezone:** `Africa/Nairobi`
> **Engineering Model:** Test-Driven Development + Domain-Driven Architecture + GitOps
> **Document Type:** Normative Engineering Standard
> **Status:** Production Engineering Standard

---

# Table of Contents

1. [Purpose](#1-purpose)
2. [Document Authority and Scope](#2-document-authority-and-scope)
3. [Normative Language](#3-normative-language)
4. [Engineering Principles](#4-engineering-principles)
5. [Engineering Priority Model](#5-engineering-priority-model)
6. [Repository Operating Model](#6-repository-operating-model)
7. [Change Risk Classification](#7-change-risk-classification)
8. [Engineering Lifecycle](#8-engineering-lifecycle)
9. [Repository Discovery Before Change](#9-repository-discovery-before-change)
10. [Test-Driven Development](#10-test-driven-development)
11. [RED Phase](#11-red-phase)
12. [GREEN Phase](#12-green-phase)
13. [REFACTOR Phase](#13-refactor-phase)
14. [Regression-First Bug Fixing](#14-regression-first-bug-fixing)
15. [Test Architecture](#15-test-architecture)
16. [Verification Integrity](#16-verification-integrity)
17. [Architecture Compliance](#17-architecture-compliance)
18. [Nix/NixOS Engineering Standards](#18-nixnixos-engineering-standards)
19. [Home Manager Standards](#19-home-manager-standards)
20. [Go Engineering Standards](#20-go-engineering-standards)
21. [Shell Engineering Standards](#21-shell-engineering-standards)
22. [Systemd Engineering Standards](#22-systemd-engineering-standards)
23. [Security Engineering Standards](#23-security-engineering-standards)
24. [Secrets Engineering](#24-secrets-engineering)
25. [Network Engineering](#25-network-engineering)
26. [Tailscale and Remote Access](#26-tailscale-and-remote-access)
27. [Observability Engineering](#27-observability-engineering)
28. [Reliability Engineering](#28-reliability-engineering)
29. [Backup and Recovery Engineering](#29-backup-and-recovery-engineering)
30. [GitOps and Deployment Engineering](#30-gitops-and-deployment-engineering)
31. [CI/CD Engineering](#31-cicd-engineering)
32. [Supply-Chain and Dependency Management](#32-supply-chain-and-dependency-management)
33. [Performance Engineering](#33-performance-engineering)
34. [Documentation Engineering](#34-documentation-engineering)
35. [Git and Change Management](#35-git-and-change-management)
36. [AI/LLM Engineering Contract](#36-aillm-engineering-contract)
37. [AI Session Workflow](#37-ai-session-workflow)
38. [AI Change Restrictions](#38-ai-change-restrictions)
39. [Emergency Changes](#39-emergency-changes)
40. [Refactoring Standards](#40-refactoring-standards)
41. [Dead Code and Deprecation](#41-dead-code-and-deprecation)
42. [TODO and Temporary Work](#42-todo-and-temporary-work)
43. [Engineering Decision Records](#43-engineering-decision-records)
44. [Definition of Done](#44-definition-of-done)
45. [Engineering Review Checklist](#45-engineering-review-checklist)
46. [Final Engineering Contract](#46-final-engineering-contract)

---

# 1. Purpose

This document defines how engineering work is performed in the
`nixos-infrastructure` repository.

It governs:

* development methodology;
* testing;
* verification;
* implementation quality;
* architecture-aware development;
* security engineering;
* reliability engineering;
* NixOS/Home Manager development;
* Go development;
* shell scripting;
* systemd services;
* networking;
* secrets;
* observability;
* backup and recovery;
* GitOps;
* CI/CD;
* dependency management;
* documentation;
* Git workflow;
* AI/LLM-assisted engineering.

The objective is not merely to make the repository compile.

The objective is to produce infrastructure that is:

```text
Correct
Secure
Reproducible
Testable
Observable
Recoverable
Maintainable
Architecturally coherent
Operationally predictable
```

---

# 2. Document Authority and Scope

`ENGINEERING.md` is the normative authority for **how engineering work is
performed**.

It does not replace the other architectural control documents.

The repository uses the following separation:

```text
ARCHITECTURE.md
    ↓
What the system is supposed to be

architecture/*.yaml
    ↓
Machine-readable architectural policy

ARCHITECTURE_AUDIT.md
    ↓
Where the repository currently conforms or deviates

ARCHITECTURE_PROGRESS.md
    ↓
How remaining architectural gaps are being closed

ENGINEERING.md
    ↓
How engineering work is performed

IVALi_FLOW.md
    ↓
How changes are developed, reviewed, merged and delivered
```

When these documents appear to conflict:

1. `ARCHITECTURE.md` governs architectural intent.
2. `architecture/*.yaml` governs machine-readable architecture policy.
3. `ENGINEERING.md` governs engineering method and quality.
4. `IVALi_FLOW.md` governs repository delivery workflow.
5. Audit and progress documents describe current state and migration.

No AI agent may resolve such a conflict by silently choosing whichever document
is more convenient.

---

# 3. Normative Language

The following words are normative.

## MUST

Absolute requirement.

## MUST NOT

Prohibited behavior.

## SHOULD

Strong recommendation. Deviations require justification.

## SHOULD NOT

Strongly discouraged. Deviations require justification.

## MAY

Permitted but optional.

## CURRENTLY

Describes present repository behavior.

## TARGET

Describes intended future behavior.

## EXAMPLE

Illustrative only.

---

# 4. Engineering Principles

The repository follows these principles.

## 4.1 Understand before changing

Do not modify infrastructure that has not been understood.

---

## 4.2 Test before implementing behavior

Behavior-changing production code follows verification-first development and,
where practical:

```text
RED → GREEN → REFACTOR
```

---

## 4.3 Prefer explicit behavior

Prefer:

```text
explicit configuration
explicit ownership
explicit dependencies
explicit failure handling
explicit security boundaries
```

over hidden or magical behavior.

---

## 4.4 Prefer the simplest correct design

Do not introduce abstraction, dependencies, services, frameworks, or layers
without a demonstrated need.

---

## 4.5 Preserve working behavior

Existing functionality must not be removed merely because a new implementation
appears cleaner.

Before replacing working behavior:

```text
understand
→ test
→ migrate
→ verify
→ remove
```

---

## 4.6 Make important properties executable

Where practical, important requirements should become:

* tests;
* assertions;
* schemas;
* linters;
* CI gates;
* runtime health checks.

---

## 4.7 Never fabricate evidence

An engineer or AI agent MUST NOT claim that something was:

* built;
* tested;
* deployed;
* restored;
* verified;
* scanned;
* observed;

unless it actually was.

---

## 4.8 Make failures visible

Failures must remain failures.

Do not suppress them merely to make:

```text
tests green
CI green
systemd healthy
```

---

## 4.9 Treat Git as engineering history

Changes should be:

* attributable;
* reviewable;
* focused;
* traceable.

---

## 4.10 Design for continuity

Another engineer or AI agent must be able to continue from the repository
without relying on hidden conversational context.

---

# 5. Engineering Priority Model

Engineering concerns are prioritized as follows:

```text
1. Security and safety
2. Data integrity
3. Recoverability
4. Reliability / availability
5. Correctness
6. Architectural integrity
7. Reproducibility
8. Maintainability
9. Observability
10. Performance
11. Convenience
12. Cosmetic preference
```

A lower-priority concern MUST NOT compromise a higher-priority concern without
an explicit decision.

---

# 6. Repository Operating Model

The repository is a declarative infrastructure system.

The preferred model is:

```text
Source
  ↓
Tests
  ↓
Architecture validation
  ↓
Build
  ↓
Review
  ↓
Merge
  ↓
GitOps
  ↓
Deployment
  ↓
Health
  ↓
Observation
  ↓
Recovery when necessary
```

The repository SHOULD remain usable at every stage of migration.

---

# 7. Change Risk Classification

Every material change should be classified.

## R0 — Documentation / formatting

Examples:

* documentation wording;
* formatting;
* comments.

## R1 — Low-risk code/configuration

Examples:

* isolated refactor;
* non-critical developer tooling;
* harmless cleanup.

## R2 — Operational change

Examples:

* service configuration;
* network rule;
* package replacement;
* user environment changes.

## R3 — High-risk infrastructure change

Examples:

* firewall;
* SSH;
* Tailscale;
* boot;
* secrets;
* systemd privilege;
* GitOps;
* deployment;
* storage;
* recovery.

## R4 — Critical infrastructure change

Examples:

* root/deployment authority;
* encryption/recovery keys;
* irreversible storage changes;
* boot/recovery chain;
* broad trust-boundary changes.

R3/R4 changes require stronger verification, smaller scopes, and explicit
rollback procedures.

---

# 8. Engineering Lifecycle

Material work follows:

```text
DISCOVER
   ↓
CLASSIFY
   ↓
DEFINE
   ↓
TEST
   ↓
IMPLEMENT
   ↓
VERIFY
   ↓
REFACTOR
   ↓
REVERIFY
   ↓
DOCUMENT
   ↓
REVIEW
   ↓
DELIVER
```

For architectural work:

```text
ARCHITECTURE
   ↓
AUDIT
   ↓
PLAN
   ↓
MIGRATE
   ↓
ENFORCE
```

---

# 9. Repository Discovery Before Change

Before modifying an unfamiliar area:

```bash
pwd
git status --short --branch
git branch --show-current
git log -10 --oneline --decorate
```

Inspect:

```text
relevant module
relevant tests
architecture manifest
exceptions
ADRs
documentation
consumers
```

Search before creating:

```bash
rg -n '<capability-or-symbol>' .
```

The default assumption is:

> The capability may already exist somewhere.

---

# 10. Test-Driven Development

TDD is the default method for new production behavior.

The preferred cycle is:

```text
Requirement
   ↓
Acceptance criterion
   ↓
Test
   ↓
Run test
   ↓
RED
   ↓
Minimum implementation
   ↓
GREEN
   ↓
REFACTOR
   ↓
Full verification
```

The test must express externally meaningful behavior.

---

# 11. RED Phase

The RED phase requires:

```text
test exists
+
test executes
+
test fails
+
failure is understood
```

The failure should occur because the required behavior does not yet exist.

A test that passes before implementation does not establish the intended TDD
cycle unless the passing test is explicitly a characterization test.

---

# 12. GREEN Phase

Implement only what is needed to satisfy the requirement.

Do not prematurely add:

* speculative abstraction;
* future features;
* unused interfaces;
* unrelated refactors;
* unrequested optimization.

The smallest correct implementation is preferred.

---

# 13. REFACTOR Phase

Once behavior is GREEN:

* simplify;
* rename;
* remove duplication;
* improve boundaries;
* improve error handling;
* reduce accidental complexity.

Tests MUST remain green.

If behavior changes intentionally, begin a new development cycle with new
verification.

---

# 14. Regression-First Bug Fixing

Every reproducible bug SHOULD become a regression test.

Preferred flow:

```text
Reproduce
   ↓
Write regression test
   ↓
RED
   ↓
Fix
   ↓
GREEN
   ↓
Refactor
   ↓
Full verification
```

A bug is not considered fully fixed if the original failure mode cannot be
reproduced and protected against where practical.

---

# 15. Test Architecture

Testing must occur at multiple levels.

```text
                 E2E
                  ▲
            Integration
                  ▲
                Module
                  ▲
                 Unit
```

---

## 15.1 Unit tests

Use for:

* pure logic;
* validation;
* parsing;
* state transitions;
* security decisions;
* error handling.

---

## 15.2 Module / configuration tests

Use for:

* Nix options;
* defaults;
* assertions;
* generated configuration;
* service definitions;
* disabled behavior;
* enabled behavior.

---

## 15.3 Integration tests

Use when crossing:

* filesystem;
* systemd;
* Nix;
* Git;
* APIs;
* databases;
* external services;
* operating-system boundaries.

Do not replace meaningful integration behavior with unrealistic mocking.

---

## 15.4 End-to-end tests

Use for important user and operator workflows.

Examples:

```text
Phone
 → Tailscale
 → Prague
 → SSH

Phone
 → Prague exit node
 → Internet

LAN
 → LocalSend
 → file transfer

Git change
 → CI
 → deployment
 → health
 → acceptance / rollback
```

---

## 15.5 Negative tests

Security-sensitive functionality MUST test forbidden behavior.

Examples:

```text
unauthorized user → denied
unauthorized device → denied
forbidden port → denied
unauthorized secret → denied
privilege escalation → denied
invalid deployment → denied
forbidden filesystem access → denied
```

---

# 16. Verification Integrity

Verification results must be truthful.

Allowed:

```text
PASS
FAIL
NOT RUN
BLOCKED
NOT APPLICABLE
UNVERIFIED
```

Never transform:

```text
FAIL
```

into:

```text
PASS
```

using:

```bash
|| true
```

or an equivalent mechanism when the failed command is part of the actual
assertion.

A command may be intentionally allowed to fail only when its failure is itself
part of the expected test behavior and the test explicitly asserts that
condition.

---

# 17. Architecture Compliance

All engineering changes MUST respect:

```text
ARCHITECTURE.md
architecture/*.yaml
active exceptions
```

Before creating a new module, service, package, or capability:

```text
Search existing implementation
        ↓
Identify current owner
        ↓
Check architecture
        ↓
Determine whether extension is possible
```

Architecture violations require either:

```text
remediation
```

or:

```text
explicit exception
```

---

# 18. Nix/NixOS Engineering Standards

NixOS configuration MUST remain:

* declarative;
* reproducible;
* composable;
* explicit;
* testable.

---

## 18.1 Module ownership

A module should represent one coherent capability.

Avoid giant modules that combine unrelated concerns.

---

## 18.2 Options

Prefer typed options.

A feature SHOULD expose:

```text
enable
configuration
defaults
assertions
```

where appropriate.

---

## 18.3 Defaults

Defaults MUST be predictable.

Dangerous capabilities SHOULD default to disabled.

Host-specific architectural invariants MAY intentionally be enabled by default
within a specific host profile.

Example:

```text
Prague:
    Tailscale = required
    Exit Node = required
```

This must not imply that all hosts inherit those capabilities.

---

## 18.4 Assertions

Use Nix assertions for invalid combinations.

Example classes:

```text
feature requires dependency
host requires hardware declaration
option combinations are incompatible
security mode requires authentication
```

---

## 18.5 Reproducibility

Avoid unnecessary dependency on:

* environment variables;
* undeclared filesystem state;
* mutable downloads;
* manual operator state;
* host-specific hidden assumptions.

---

## 18.6 Evaluation safety

Nix evaluation should be deterministic.

Avoid:

```nix
builtins.getEnv
```

and similar mechanisms unless there is a deliberate and documented reason.

---

# 19. Home Manager Standards

Home Manager configuration MUST:

* remain declarative;
* respect host boundaries;
* avoid duplicate ownership;
* avoid hidden imperative installation;
* preserve user state where required;
* integrate with system configuration through explicit interfaces.

User configuration must not silently become a second system-configuration
authority.

---

# 20. Go Engineering Standards

Go code must remain idiomatic and maintainable.

---

## 20.1 Package ownership

Each package must have a coherent responsibility.

Avoid miscellaneous "utils" packages that become uncontrolled dependency
centers.

---

## 20.2 Interfaces

Use interfaces where they provide:

* meaningful abstraction;
* testability;
* dependency inversion;
* architecture boundaries.

Do not create interfaces purely because an abstraction seems theoretically
clean.

---

## 20.3 Error handling

Errors MUST be checked.

Provide contextual errors where useful:

```go
return fmt.Errorf("deploy generation %s: %w", generation, err)
```

Do not silently discard errors.

---

## 20.4 Context

Long-running and external operations SHOULD propagate `context.Context`.

---

## 20.5 Panics

Panics MUST NOT be used for ordinary operational failure.

Expected failure is represented as an error.

---

## 20.6 Command execution

Avoid arbitrary shell execution.

Prefer:

```text
validated input
→ typed operation
→ controlled adapter
```

over:

```text
HTTP/API input
→ arbitrary command string
→ shell
```

---

## 20.7 Go test discipline

New Go behavior follows:

```text
*_test.go
→ RED
→ implementation
→ GREEN
→ refactor
```

---

# 21. Shell Engineering Standards

Scripts must be deliberate operational tools, not hidden configuration systems.

Where applicable:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Scripts MUST:

* validate input;
* quote variables;
* check failures;
* avoid `eval`;
* avoid secret leakage;
* use explicit dependencies;
* behave idempotently where practical.

At minimum:

```bash
bash -n script.sh
```

Meaningful operational behavior must also receive behavioral tests.

---

# 22. Systemd Engineering Standards

Every persistent unit must have an owner and explicit lifecycle.

At minimum define as appropriate:

```text
User
Group
ExecStart
Restart
Timeout
Dependencies
StateDirectory
RuntimeDirectory
Environment
ReadWritePaths
```

Security-sensitive services SHOULD use:

```text
NoNewPrivileges
ProtectSystem
ProtectHome
PrivateTmp
PrivateDevices
RestrictAddressFamilies
CapabilityBoundingSet
SystemCallFilter
```

Security controls must be validated against actual service requirements.

Do not add hardening options blindly.

---

# 23. Security Engineering Standards

Security must be designed into implementation.

Every security-sensitive change must consider:

```text
asset
threat
trust boundary
privilege
exposure
failure mode
recovery
```

---

## 23.1 Least privilege

Prefer:

```text
minimum user
minimum capabilities
minimum filesystem access
minimum network access
minimum secret scope
```

---

## 23.2 Authentication

Authentication must be explicit.

Do not rely on an undocumented assumption that:

```text
"it is inside the network, so it is trusted."
```

---

## 23.3 Authorization

Authorization must be distinct from authentication.

A user being authenticated does not automatically imply broad authorization.

---

## 23.4 Privilege escalation

Any path to root must be treated as a security boundary.

Document:

```text
who may invoke it
what they may invoke
what inputs are allowed
what output is produced
```

---

# 24. Secrets Engineering

Secrets MUST be treated as controlled assets.

Preferred model:

```text
SOPS
+
age
+
explicit consumer scope
```

Secrets MUST NOT be stored as plaintext in:

* Git;
* Nix expressions;
* Go source;
* shell scripts;
* documentation;
* CI logs;
* debug output.

Secrets SHOULD be scoped by:

```text
host
service
purpose
trust boundary
```

Every important secret SHOULD have:

```text
owner
creation method
rotation method
revocation method
recovery method
compromise response
```

---

# 25. Network Engineering

Network configuration must have clear ownership.

Every listening service should have:

```text
owner
port
protocol
bind address
purpose
exposure scope
authentication
firewall policy
```

Firewall policy must be explicit.

Avoid broad rules whose real meaning is:

```text
everything except interface X
```

when the intended policy is:

```text
LAN only
Tailscale only
management only
```

---

# 26. Tailscale and Remote Access

Tailscale is a security/networking boundary, not merely a connectivity tool.

The repository's intended model includes:

```text
Prague
 ├── Tailscale
 ├── tag:infra
 └── tag:exit-node

Phone
 └── tag:user
```

Prague has a deliberate architectural requirement:

```text
Tailscale MUST remain enabled.
Prague MUST remain capable of operating as an exit node.
```

The current working Tailscale ACL is the baseline.

Do not change the ACL merely to modernize syntax.

Any policy migration requires:

* syntax validation;
* policy validation;
* client testing;
* rollback.

---

## 26.1 Prague gateway verification

The gateway must be treated as one tested capability:

```text
Tailscale
+
forwarding
+
NAT
+
firewall
+
uplink
+
DNS
+
recovery
```

Required runtime workflows:

```text
Phone
→ Tailscale
→ Prague
```

and:

```text
Phone
→ Tailscale
→ Prague exit node
→ Internet
```

These are separate tests.

---

# 27. Observability Engineering

Important systems must expose enough information to answer:

```text
Is it working?
Is it degraded?
What failed?
Why did it fail?
What changed?
How do I recover?
```

Observability should cover as appropriate:

```text
health
metrics
logs
deployment state
security events
backup freshness
gateway state
rollback state
```

Observability must respect data classification.

Do not log secrets.

---

# 28. Reliability Engineering

Reliability is designed, not assumed.

For every critical capability identify:

```text
failure mode
detection
retry
timeout
fallback
recovery
observability
```

Critical capabilities SHOULD have defined:

```text
SLO
RPO
RTO
```

where meaningful.

---

# 29. Backup and Recovery Engineering

Backups are not complete merely because a backup command succeeds.

A valid backup program should define:

```text
what
where
encryption
retention
verification
restore procedure
monitoring
failure behavior
```

Recovery must be periodically verified where practical.

Rollback is part of the deployment architecture.

---

# 30. GitOps and Deployment Engineering

Deployment should follow:

```text
Change
 ↓
Tests
 ↓
Review
 ↓
CI
 ↓
Merge
 ↓
GitOps reconciliation
 ↓
Activation
 ↓
Health gate
 ↓
Acceptance
```

Failure:

```text
Health failure
 ↓
Rollback
 ↓
Verify
 ↓
Alert
```

---

## 30.1 Deployment privilege

GitOps MUST NOT become a general-purpose root shell.

Preferred model:

```text
unprivileged reconciler
        ↓
validated deployment request
        ↓
narrow privileged activation
        ↓
root
```

---

## 30.2 Deployment locking

Concurrent deployment/rollback operations MUST be serialized.

Use an authoritative lock rather than process-name heuristics.

---

## 30.3 Deployment exit codes

Meaning MUST remain unambiguous:

```text
0 = success
non-zero = failure
```

Do not redefine failure as success to make systemd or monitoring quieter.

---

# 31. CI/CD Engineering

CI is a verification system.

It must validate the repository rather than become a hidden deployment
mechanism.

CI SHOULD cover:

```text
formatting
architecture
security
unit tests
integration tests
host evaluation
host builds
dependency checks
secret scanning
shell validation
Go validation
```

---

## 31.1 Host matrix

All supported hosts must be evaluated appropriately.

Do not validate only the host most commonly used by the developer.

---

## 31.2 CI failure integrity

A failing required gate must fail CI.

Do not conceal failures using:

```text
|| true
```

or equivalent unconditional success behavior.

---

# 32. Supply-Chain and Dependency Management

Every important dependency introduces:

```text
security
maintenance
reproducibility
operational
license
```

considerations.

Before adding a dependency:

1. search for existing functionality;
2. assess maintenance;
3. assess security;
4. assess transitive cost;
5. assess reproducibility;
6. document why it is needed.

Nix inputs and other external dependencies should remain pinned/reviewable.

Lockfile changes deserve deliberate review.

---

## 32.1 Source-to-deployment provenance

Where practical, preserve:

```text
Commit SHA
 ↓
CI result
 ↓
Build
 ↓
Artifact
 ↓
Deployment
 ↓
Generation
```

A production system should be able to answer:

> Which source revision produced this deployed state?

---

# 33. Performance Engineering

Performance changes must be evidence-based.

Preferred:

```text
Measure
 ↓
Identify bottleneck
 ↓
Test
 ↓
Change
 ↓
Measure
 ↓
Compare
```

Do not optimize based purely on intuition.

Performance work must not compromise:

```text
security
correctness
reliability
maintainability
```

---

# 34. Documentation Engineering

Documentation is part of the engineering system.

Documentation MUST accurately describe behavior.

Update documentation when:

* architecture changes;
* operational procedures change;
* security assumptions change;
* deployment behavior changes;
* recovery behavior changes.

Do not duplicate the same source of truth across multiple documents without
a clear reason.

---

# 35. Git and Change Management

`main` represents reviewed production-ready state.

Development should normally occur on branches:

```text
feature/<name>
fix/<name>
refactor/<name>
security/<name>
test/<name>
docs/<name>
```

Changes should be:

* focused;
* reviewable;
* attributable;
* reversible where practical.

---

## 35.1 Preserve user work

Before modifying:

```bash
git status --short
git diff
```

Never overwrite unrelated changes.

---

## 35.2 Destructive Git operations

Do not casually use:

```text
git reset --hard
git clean -fd
git restore .
git checkout -- .
```

These require explicit authorization when there is any possibility of
discarding existing work.

---

## 35.3 Commit quality

Commits should explain intent.

Avoid commits that combine unrelated:

```text
feature
refactor
security change
dependency migration
formatting
```

without necessity.

---

# 36. AI/LLM Engineering Contract

AI agents are engineering contributors.

They are not architectural authorities.

AI agents MUST:

* inspect before changing;
* follow repository rules;
* follow TDD;
* preserve existing changes;
* respect architecture;
* run relevant verification;
* report actual results;
* document meaningful changes;
* maintain session continuity.

---

## 36.1 AI agents MUST NOT

AI agents MUST NOT:

* fabricate verification;
* fabricate runtime results;
* invent files;
* invent Nix options;
* invent desktop IDs;
* silently alter architecture policy;
* weaken tests to obtain GREEN;
* remove security controls without justification;
* add arbitrary root execution;
* add plaintext secrets;
* bypass Git workflow;
* discard user changes;
* silently expand scope;
* claim a deployment succeeded when it was not verified.

---

# 37. AI Session Workflow

Every significant AI session should follow:

```text
BOOTSTRAP
   ↓
INSPECT
   ↓
UNDERSTAND
   ↓
CLASSIFY RISK
   ↓
PLAN
   ↓
WRITE VERIFICATION
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
DOCUMENT
   ↓
HANDOFF
```

At bootstrap, read the relevant governing files, especially:

```text
AGENTS.md
ENGINEERING.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
CONTRIBUTING.md
IVALi_FLOW.md
README.md
CONTEXT_HANDOFF.md
```

---

# 38. AI Change Restrictions

An AI agent must not silently expand:

```text
requested feature
```

into:

```text
unrelated architecture migration
dependency rewrite
database migration
security redesign
platform replacement
```

If broader work becomes necessary:

```text
identify
→ isolate
→ justify
→ verify
```

---

## 38.1 Search before creating

Before creating a new:

* service;
* module;
* package;
* helper;
* script;
* abstraction;

search for existing implementations.

---

## 38.2 Reuse before duplicating

Preferred order:

```text
reuse
→ extend
→ refactor
→ replace
→ create new
```

A new implementation requires justification when an existing capability is
available.

---

## 38.3 AI verification truthfulness

AI output must explicitly distinguish:

```text
EXECUTED
```

from:

```text
INFERRED
```

and:

```text
UNVERIFIED
```

An AI agent must never infer runtime success from a static build.

---

# 39. Emergency Changes

Emergency work is permitted when required to:

* restore service;
* preserve data;
* prevent active security compromise;
* recover access;
* prevent imminent damage.

Emergency work may temporarily bypass ordinary sequencing.

It MUST still:

1. minimize change scope;
2. preserve evidence;
3. document what changed;
4. verify immediate outcome;
5. create follow-up tests;
6. perform architecture review afterward.

Emergency status is not permission for permanent process bypass.

---

# 40. Refactoring Standards

Refactoring must be behavior-preserving unless the behavior change is
intentional.

Before refactoring:

```text
understand
→ test
→ baseline
→ refactor
→ verify
```

Large refactors should be split into smaller verified changes.

Avoid combining unrelated feature and refactor work.

---

# 41. Dead Code and Deprecation

Dead code should be removed when confidently identified.

Before removal verify:

```text
no consumers
no dynamic references
no generated dependency
no documented required behavior
```

Deprecated functionality should have:

```text
reason
replacement
migration path
removal condition
```

Do not let compatibility code become permanent without deliberate approval.

---

# 42. TODO and Temporary Work

Temporary work must identify:

```text
What
Why
Risk
Owner
Follow-up
Removal condition
```

Bad:

```text
TODO: fix later
```

Better:

```text
TODO:
Replace temporary deployment compatibility layer with the deployment service
after ARC-017 is complete.
Owner: Automation
Removal condition: all consumers migrated
```

---

# 43. Engineering Decision Records

Significant engineering decisions should be documented.

Typical ADR subjects:

```text
architecture
security
deployment
recovery
networking
major dependency choice
data storage
service-boundary changes
```

Decision records should contain:

```text
Context
Decision
Alternatives
Reason
Consequences
Security implications
Operational implications
Migration implications
```

ADRs explain decisions.

They do not replace current implementation documentation.

---

# 44. Definition of Done

A material change is complete only when applicable criteria are satisfied.

## Requirement

* [ ] Requirement understood.
* [ ] Scope defined.
* [ ] Acceptance criteria defined.

## Architecture

* [ ] Correct domain identified.
* [ ] Capability ownership is correct.
* [ ] Dependencies are valid.
* [ ] State ownership is valid.
* [ ] Architecture policy remains satisfied.
* [ ] Required manifests updated.

## TDD

* [ ] Test written first where applicable.
* [ ] RED demonstrated where meaningful.
* [ ] Failure understood.
* [ ] Minimum implementation completed.
* [ ] GREEN demonstrated.
* [ ] Refactoring completed where useful.
* [ ] Regression coverage exists.

## Security

* [ ] Least privilege considered.
* [ ] Secret handling reviewed.
* [ ] Network exposure reviewed.
* [ ] Filesystem access reviewed.
* [ ] Negative security behavior tested where appropriate.

## Reliability

* [ ] Failure behavior understood.
* [ ] Recovery behavior defined where required.
* [ ] Rollback considered.
* [ ] Observability exists where required.

## Verification

* [ ] Relevant tests pass.
* [ ] Relevant architecture tests pass.
* [ ] Nix evaluation passes.
* [ ] Build passes where required.
* [ ] Runtime behavior verified where required.
* [ ] No required verification was silently skipped.

## Git

* [ ] Existing user work preserved.
* [ ] Diff reviewed.
* [ ] No unrelated changes remain.
* [ ] Change follows repository workflow.

## Documentation

* [ ] Documentation updated where behavior changed.
* [ ] ADR updated where required.
* [ ] Handoff updated where session continuity requires it.

---

# 45. Engineering Review Checklist

Before merge, reviewers should ask:

## Correctness

```text
Does it solve the actual problem?
```

## TDD

```text
Does the test prove the behavior?
Was the failure understood?
```

## Architecture

```text
Is the ownership correct?
Are dependencies correct?
Did coupling increase?
```

## Security

```text
Did privilege increase?
Did exposure increase?
Were secrets handled correctly?
```

## Reliability

```text
What happens when it fails?
Can the system recover?
```

## Observability

```text
Can an operator tell whether it works?
Can they diagnose failure?
```

## Reproducibility

```text
Can another machine/CI runner reproduce the result?
```

## Maintainability

```text
Did this make the repository simpler or more complex?
Is the complexity justified?
```

## AI safety

```text
Did the agent change only what was necessary?
Were existing tests preserved?
Was verification truthful?
```

---

# 46. Final Engineering Contract

Every contributor and every AI agent working on this repository operates under
the following contract:

> **Understand before changing.**

> **Search before creating.**

> **Test before implementing behavior.**

> **Make the test fail first where meaningful.**

> **Implement the minimum correct behavior.**

> **Make the test pass.**

> **Refactor while preserving behavior.**

> **Protect architecture.**

> **Protect secrets.**

> **Minimize privilege.**

> **Make failures visible.**

> **Verify actual runtime behavior.**

> **Preserve existing work.**

> **Document important decisions.**

> **Keep changes reversible where practical.**

> **Never fabricate evidence.**

> **Leave the repository understandable to the next engineer or AI agent.**

The fundamental engineering loop is:

```text
                    REQUIREMENT
                         │
                         ▼
                  UNDERSTAND SYSTEM
                         │
                         ▼
                  DEFINE BEHAVIOR
                         │
                         ▼
                    WRITE TEST
                         │
                         ▼
                       RED
                         │
                         ▼
                 MINIMUM IMPLEMENTATION
                         │
                         ▼
                      GREEN
                         │
                         ▼
                     REFACTOR
                         │
                         ▼
                    VERIFY
                         │
                         ▼
                    DOCUMENT
                         │
                         ▼
                      REVIEW
                         │
                         ▼
                     DELIVER
                         │
                         ▼
                     OBSERVE
                         │
                         ▼
                   IMPROVE SAFELY
```

The repository is not considered engineered merely because:

```text
it builds
```

It is engineered when:

```text
behavior is specified
+
tests protect behavior
+
architecture is respected
+
security boundaries are explicit
+
the result is reproducible
+
failures are observable
+
recovery is understood
+
verification is truthful
+
the change is maintainable
```

**Test first. Build second. Refactor third. Verify always.**
